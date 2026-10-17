import AppKit
import MapKit

/// The big world's map on the Mac's own 大世界 page (the phone's is pwa/app/components/WorldMap.vue): the real map (Apple's,
/// muted, without its own places), with only the cell picked and the held ones outlined (yours yellow, others' red), others'
/// built-up land as a dark red wall, others' talents (伏擊 orange dashes, 腐化大地 purple), and over the cells what is there:
/// a lair's strongest foe and level, a great monster and its blood, a camp's home or town as a pixel building flying its
/// race's flag, a held cell's face and garrison. Parties on the road walk their dashed road (others' coming to attack in
/// red); the way the cell picked would be walked is a yellow dotted line. Drag, scroll and pinch to look round; click a cell.
final class WorldMapView: NSView, MKMapViewDelegate {
    struct Party {
        let id: String
        let path: [CLLocationCoordinate2D]
        let setOutAt: Date
        let arriveAt: Date
        let race: String
        let hostile: Bool
    }

    var onSelect: ((String) -> Void)?
    /// The map was dragged well away from where the page last looked (it may fetch more cells there).
    var onPan: ((CLLocationCoordinate2D) -> Void)?
    var onHome: (() -> Void)?

    private let map = MKMapView()
    private let homeButton = NSButton()
    private var cells: [WorldCell] = []
    private var mine: String?
    private var selected: String?
    private var walkingTo: Set<String> = []
    private var alerts: Set<String> = []
    private var parties: [Party] = []
    private var plan: [CLLocationCoordinate2D]?
    /// Where the page last asked the map to look (a drag farther than 300 m from it is told).
    private var asked = CLLocationCoordinate2D()
    private var marks: [String: (key: String, mark: CellMark)] = [:]
    private var partyMarks: [String: PartyMark] = [:]
    private var ticker: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        map.delegate = self
        // (always the light map: the pixel foes are dark, and the phone's map is light too)
        map.appearance = NSAppearance(named: .aqua)
        let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        config.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = config
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false
        map.showsZoomControls = true
        // (about the phone's zoom 12.5 to 17.5)
        map.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 350, maxCenterCoordinateDistance: 16_000)
        map.translatesAutoresizingMaskIntoConstraints = false
        addSubview(map)
        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked(_:)))
        click.delaysPrimaryMouseButtonEvents = false
        map.addGestureRecognizer(click)

        homeButton.bezelStyle = .circular
        homeButton.isBordered = true
        homeButton.imageScaling = .scaleProportionallyUpOrDown
        homeButton.toolTip = "回到我的營地"
        homeButton.target = self
        homeButton.action = #selector(goHome)
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        homeButton.isHidden = true
        addSubview(homeButton)
        NSLayoutConstraint.activate([
            map.leadingAnchor.constraint(equalTo: leadingAnchor), map.trailingAnchor.constraint(equalTo: trailingAnchor),
            map.topAnchor.constraint(equalTo: topAnchor), map.bottomAnchor.constraint(equalTo: bottomAnchor),
            homeButton.topAnchor.constraint(equalTo: topAnchor, constant: 10), homeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            homeButton.widthAnchor.constraint(equalToConstant: 40), homeButton.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    /// The parties move along their roads every second while the map is up.
    func start() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.moveParties() }
    }

    func stop() {
        ticker?.invalidate()
        ticker = nil
    }

    /// The race whose face is on the "back to my camp" button (nil: no camp yet, no button).
    func setHome(race: String?) {
        homeButton.isHidden = race == nil
        if let race, let face = WorldArt.face(race) {
            let img = NSImage(cgImage: face, size: NSSize(width: 24, height: 24))
            homeButton.image = img
        }
    }

    /// Where the map looks now.
    var center: CLLocationCoordinate2D { map.centerCoordinate }

    /// Looks at `c` (gliding there when it is near, jumping when it is far); `meters` across, or the zoom as it is.
    func look(at c: CLLocationCoordinate2D, meters: Double? = nil, animated: Bool = true) {
        asked = c
        if let meters {
            map.setRegion(MKCoordinateRegion(center: c, latitudinalMeters: meters, longitudinalMeters: meters), animated: animated)
        } else if WorldGrid.meters(map.centerCoordinate, c) > 150 {
            map.setCenter(c, animated: animated && WorldGrid.meters(map.centerCoordinate, c) < 20_000)
        }
    }

    func show(cells: [WorldCell], mine: String?, selected: String?, walkingTo: [String], alerts: [String], parties: [Party], plan: [CLLocationCoordinate2D]?) {
        self.cells = cells
        self.mine = mine
        self.selected = selected
        self.walkingTo = Set(walkingTo)
        self.alerts = Set(alerts)
        self.parties = parties
        self.plan = plan
        drawShapes()
        drawMarks()
        moveParties()
    }

    /// Only the picked cell changed (or the way to it): no icons made again.
    func pick(_ selected: String?, plan: [CLLocationCoordinate2D]?) {
        self.selected = selected
        self.plan = plan
        drawShapes()
    }

    // MARK: drawing

    private enum Look { case mine, theirs, boss, free, wall, blight, ambush, picked, target }

    private final class CellShape: MKPolygon { var look = Look.free }
    /// A wash over the whole map, under everything drawn on it: the light map is too bright beside a dark window.
    private final class Dim: MKPolygon {}
    private lazy var dim: Dim = {
        let r = MKMapRect.world
        let corners = [MKMapPoint(x: r.minX, y: r.minY), MKMapPoint(x: r.maxX, y: r.minY), MKMapPoint(x: r.maxX, y: r.maxY), MKMapPoint(x: r.minX, y: r.maxY)]
        return Dim(points: corners, count: corners.count)
    }()
    private final class Road: MKPolyline {
        enum Kind { case party, hostile, plan }
        var kind = Kind.party
    }
    final class CellMark: MKPointAnnotation { var image: NSImage? }
    final class PartyMark: MKPointAnnotation { var image: NSImage? }

    private func shape(_ c: WorldCell, _ look: Look, drawn: Double = 0.9) -> CellShape {
        let ring = WorldGrid.ring(c.coordinate, drawn: drawn)
        let s = CellShape(coordinates: ring, count: ring.count)
        s.look = look
        return s
    }

    /// The outlines and roads (few: only the cells with something to show), all made again on each change.
    private func drawShapes() {
        map.removeOverlays(map.overlays)
        var shapes: [MKOverlay] = [dim]
        var picked: CellShape?
        for c in cells {
            if let owner = c.owner { shapes.append(shape(c, owner.id == mine ? .mine : .theirs)) } else if c.boss != nil { shapes.append(shape(c, .boss)) }
            if c.blocks == true { shapes.append(shape(c, .wall)) }
            if c.threats?.contains("blight") == true { shapes.append(shape(c, .blight)) }
            if c.threats?.contains("ambush") == true { shapes.append(shape(c, .ambush, drawn: 0.82)) }
            if walkingTo.contains(c.cell) { shapes.append(shape(c, .target, drawn: 0.8)) }
            if c.cell == selected { picked = shape(c, .picked) }
        }
        if picked == nil, let selected {
            let ring = WorldGrid.ring(WorldGrid.center(selected))
            let s = CellShape(coordinates: ring, count: ring.count)
            s.look = .picked
            picked = s
        }
        for p in parties where p.path.count > 1 {
            let road = Road(coordinates: p.path, count: p.path.count)
            road.kind = p.hostile ? .hostile : .party
            shapes.append(road)
        }
        if let plan, plan.count > 1 {
            let road = Road(coordinates: plan, count: plan.count)
            road.kind = .plan
            shapes.append(road)
        }
        if let picked { shapes.append(picked) }
        map.addOverlays(shapes, level: .aboveRoads)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
            NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
        }
        if let road = overlay as? Road {
            let r = MKPolylineRenderer(polyline: road)
            switch road.kind {
            case .party: r.strokeColor = .white.withAlphaComponent(0.9); r.lineWidth = 3; r.lineDashPattern = [6, 4]
            case .hostile: r.strokeColor = color(0xff3a2a, 0.9); r.lineWidth = 4; r.lineDashPattern = [8, 6]
            case .plan: r.strokeColor = color(0xf3d36b); r.lineWidth = 4; r.lineCap = .round; r.lineDashPattern = [0.5, 8]
            }
            return r
        }
        if let d = overlay as? Dim {
            let r = MKPolygonRenderer(polygon: d)
            let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            r.fillColor = color(0x1c2416, dark ? 0.42 : 0.18) // (a dusky green-brown, the camp's evening)
            return r
        }
        guard let s = overlay as? CellShape else { return MKOverlayRenderer(overlay: overlay) }
        let r = MKPolygonRenderer(polygon: s)
        switch s.look {
        case .mine: r.fillColor = color(0xffd84a, 0.16); r.strokeColor = color(0xffd84a); r.lineWidth = 2.5
        case .theirs: r.fillColor = color(0xe04a3a, 0.14); r.strokeColor = color(0xe04a3a); r.lineWidth = 2.5
        case .boss: r.fillColor = color(0xff3a2a, 0.16); r.strokeColor = color(0xff3a2a); r.lineWidth = 2.5
        case .wall: r.fillColor = color(0x7a1a10, 0.32); r.strokeColor = color(0x5a0f08); r.lineWidth = 4
        case .blight: r.fillColor = color(0x5b2a86, 0.22)
        case .ambush: r.strokeColor = color(0xff8a1e, 0.85); r.lineWidth = 2; r.lineDashPattern = [3, 3]
        case .target: r.strokeColor = .white; r.lineWidth = 2; r.lineDashPattern = [6, 4]
        case .picked: r.strokeColor = .white; r.lineWidth = 3; r.fillColor = .white.withAlphaComponent(0.12)
        case .free: break
        }
        return r
    }

    /// The icons over the cells: only those whose cell changed are made again.
    private func drawMarks() {
        var seen = Set<String>()
        for c in cells {
            seen.insert(c.cell)
            let key = markKey(c)
            if marks[c.cell]?.key == key { continue }
            if let old = marks.removeValue(forKey: c.cell) { map.removeAnnotation(old.mark) }
            guard let image = markImage(c) else { continue }
            let mark = CellMark()
            mark.coordinate = c.coordinate
            mark.image = image
            marks[c.cell] = (key, mark)
            map.addAnnotation(mark)
        }
        for (cell, m) in marks where !seen.contains(cell) {
            map.removeAnnotation(m.mark)
            marks.removeValue(forKey: cell)
        }
    }

    private func markKey(_ c: WorldCell) -> String {
        var parts: [String] = []
        if let o = c.owner { parts.append("o\(o.id == mine)\(o.race)\(c.garrison)\(c.town)\(c.hub ?? "")\(c.home ?? false)\(c.nest)\(o.level ?? 1)") }
        if let b = c.boss { parts.append("b\(b.kind)\(100 * b.hp / max(1, b.maxHp))") }
        if let l = c.lair { parts.append("l\(l.kind)\(l.level)\(l.boss ?? false)\(WorldNames.shared.leader(l.foes))") }
        parts.append("\(c.landmark?.kind ?? "")\(c.meteor != nil)\(alerts.contains(c.cell))")
        return parts.joined(separator: "|")
    }

    /// A label over the map: bold, with a dark outline so it reads on any ground.
    private static func label(_ text: String, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .heavy), .foregroundColor: color,
                                                      .strokeColor: NSColor(white: 0.1, alpha: 1), .strokeWidth: -4])
    }

    private static let gold = NSColor(srgbRed: 1, green: 0.85, blue: 0.3, alpha: 1)
    private static let pink = NSColor(srgbRed: 1, green: 0.604, blue: 0.541, alpha: 1)

    /// A cell's icon as one picture (nil: nothing to show there): what stands there on top, a label under it, and in the corners
    /// ⚔️ (attacked lately, or a party on its way) and the real place standing in it.
    private func markImage(_ c: WorldCell) -> NSImage? {
        let names = WorldNames.shared
        var picture: (draw: (CGRect) -> Void, size: NSSize)?
        var text: NSAttributedString?
        var hp: Double?
        if let o = c.owner {
            let color = o.id == mine ? Self.gold : Self.pink
            if c.home == true || c.town || c.hub != nil {
                let img = WorldArt.building(town: c.home != true, race: o.race, level: o.level ?? 1, scale: 5.0 / 3.0)
                picture = ({ img.draw(in: $0) }, img.size)
                let sign = c.hub.map { ["fortress": "🏰", "workstead": "⚒️", "sanctuary": "⛩️"][$0].map { "\($0) " } ?? "" } ?? ""
                text = Self.label("\(sign)\(c.garrison)\(c.home == true ? " 營地" : c.hub != nil ? "" : " 城")", color: color)
            } else {
                let face = WorldArt.face(o.race)
                picture = ({ r in face.map { Self.pixel($0, in: r) } }, NSSize(width: 22, height: 22))
                text = Self.label("\(c.garrison)\(c.town ? " 城" : c.nest != "none" ? " 巢" : "")", color: color)
            }
        } else if let b = c.boss {
            let foe = WorldArt.foe(b.kind)
            picture = ({ r in foe.map { Self.pixel($0, in: r) } }, NSSize(width: 36, height: 36))
            hp = Double(b.hp) / Double(max(1, b.maxHp))
        } else if let l = c.lair {
            let foe = WorldArt.foe(l.kind == "enemy_town" ? "enemy_town" : names.leader(l.foes))
            let n: CGFloat = l.boss == true ? 30 : 22
            picture = ({ r in foe.map { Self.pixel($0, in: r) } }, NSSize(width: n, height: n))
            text = Self.label("\(l.boss == true ? "👑 " : "")Lv\(l.level)", color: l.boss == true ? Self.gold : .white)
        } else if c.meteor != nil {
            let star = NSAttributedString(string: "☄️", attributes: [.font: NSFont.systemFont(ofSize: 22)])
            picture = ({ r in star.draw(at: NSPoint(x: r.minX, y: r.minY)) }, star.size())
            text = Self.label("流星", color: Self.gold)
        } else if c.landmark == nil && !alerts.contains(c.cell) {
            return nil
        }
        let alert = alerts.contains(c.cell)
        let landmark = c.landmark.flatMap { names.landmark($0.kind)?.icon ?? "📍" }
        let pic = picture?.size ?? .zero
        let labelSize = text?.size() ?? .zero
        let width = max(44, pic.width, labelSize.width) + 24
        let height = pic.height + (text != nil ? labelSize.height : 0) + (hp != nil ? 8 : 0) + 12
        return NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            var y: CGFloat = 6
            if let picture {
                picture.draw(CGRect(x: (width - pic.width) / 2, y: y, width: pic.width, height: pic.height))
                y += pic.height
            }
            if let hp {
                let bar = CGRect(x: (width - 44) / 2, y: y + 1, width: 44, height: 6)
                NSColor.black.withAlphaComponent(0.55).setFill()
                NSBezierPath(roundedRect: bar, xRadius: 3, yRadius: 3).fill()
                NSColor(srgbRed: 1, green: 0.29, blue: 0.23, alpha: 1).setFill()
                NSBezierPath(roundedRect: CGRect(x: bar.minX, y: bar.minY, width: bar.width * max(0, min(1, hp)), height: bar.height), xRadius: 3, yRadius: 3).fill()
                y += 8
            }
            if let text { text.draw(at: NSPoint(x: (width - labelSize.width) / 2, y: y - 1)) }
            let corner = NSFont.systemFont(ofSize: picture == nil ? 15 : 12)
            if alert {
                let s = NSAttributedString(string: "⚔️", attributes: [.font: corner])
                s.draw(at: picture == nil ? NSPoint(x: (width - s.size().width) / 2, y: 2) : NSPoint(x: 0, y: 0))
            }
            if let landmark {
                let s = NSAttributedString(string: landmark, attributes: [.font: corner])
                s.draw(at: picture == nil && !alert ? NSPoint(x: (width - s.size().width) / 2, y: 2) : NSPoint(x: width - s.size().width, y: 0))
            }
            return true
        }
    }

    /// A pixel picture drawn sharp (in a flipped context: turned the right way up).
    private static func pixel(_ image: CGImage, in r: CGRect) {
        guard let g = NSGraphicsContext.current?.cgContext else { return }
        g.saveGState()
        g.interpolationQuality = .none
        g.translateBy(x: r.minX, y: r.maxY)
        g.scaleBy(x: 1, y: -1)
        g.draw(image, in: CGRect(origin: .zero, size: r.size))
        g.restoreGState()
    }

    private static func partyImage(_ race: String, hostile: Bool) -> NSImage {
        let face = WorldArt.face(race)
        return NSImage(size: NSSize(width: 28, height: 28), flipped: true) { _ in
            let glow = NSShadow()
            glow.shadowColor = hostile ? NSColor(srgbRed: 1, green: 0.23, blue: 0.16, alpha: 1) : .white
            glow.shadowBlurRadius = hostile ? 5 : 3
            glow.set()
            if let face { pixel(face, in: CGRect(x: 3, y: 3, width: 22, height: 22)) }
            return true
        }
    }

    /// The parties' little faces, where along the road they are by now.
    private func moveParties() {
        let now = Date()
        var live = Set<String>()
        for p in parties {
            live.insert(p.id)
            let k = min(1, max(0, now.timeIntervalSince(p.setOutAt) / max(1, p.arriveAt.timeIntervalSince(p.setOutAt))))
            let at = WorldGrid.along(p.path, k)
            if let known = partyMarks[p.id] {
                known.coordinate = at
                continue
            }
            let m = PartyMark()
            m.coordinate = at
            m.image = Self.partyImage(p.race, hostile: p.hostile)
            partyMarks[p.id] = m
            map.addAnnotation(m)
        }
        for (id, m) in partyMarks where !live.contains(id) {
            map.removeAnnotation(m)
            partyMarks.removeValue(forKey: id)
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let image: NSImage?, reuse: String
        if let m = annotation as? CellMark { image = m.image; reuse = "cell" } else if let m = annotation as? PartyMark { image = m.image; reuse = "party" } else { return nil }
        let v = mapView.dequeueReusableAnnotationView(withIdentifier: reuse) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: reuse)
        v.annotation = annotation
        v.image = image
        v.isEnabled = false // (a click goes through to the cell under it)
        v.canShowCallout = false
        v.displayPriority = .required
        v.zPriority = reuse == "party" ? .max : .defaultUnselected
        v.collisionMode = .none
        return v
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        drawShapes() // (the wash is darker in dark mode)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let c = mapView.centerCoordinate
        if WorldGrid.meters(c, asked) > 300 {
            asked = c
            onPan?(c)
        }
    }

    @objc private func clicked(_ g: NSClickGestureRecognizer) {
        let at = map.convert(g.location(in: map), toCoordinateFrom: map)
        onSelect?(WorldGrid.cellAt(at))
    }

    @objc private func goHome() { onHome?() }
}
