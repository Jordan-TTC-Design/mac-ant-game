<script setup lang="ts">
// A test page for the iPhone home-screen app, whose page is shorter than the screen (by the status bar): five ways of
// putting a bar at the bottom, side by side, and the sizes the phone reports. A screenshot says which one reaches the
// bottom edge. Not linked from anywhere: open /debug-bottom by hand. (Delete once the tab bar is settled.)
import { measureViewport, type ViewportSizes } from "~/utils/viewport";

const sizes = ref<ViewportSizes | null>(null);
const units = ref<Record<string, number>>({});
const screenTop = ref(0);
function probe(css: string): number {
  const el = document.createElement("div");
  el.style.cssText = `position:absolute;visibility:hidden;top:0;left:0;width:1px;height:${css}`;
  document.body.appendChild(el);
  const h = el.getBoundingClientRect().height;
  el.remove();
  return Math.round(h);
}
function measure() {
  sizes.value = measureViewport();
  units.value = { "100vh": probe("100vh"), "100lvh": probe("100lvh"), "100svh": probe("100svh"), "100dvh": probe("100dvh"), "100%": probe("100%") };
  screenTop.value = Math.max(screen.width, screen.height) - 44;
}
const saved = { html: "", body: "" };
onMounted(() => {
  // (the bars below must not be cut off by the page's own "never scroll" rule)
  saved.html = document.documentElement.style.overflow;
  saved.body = document.body.style.overflow;
  document.documentElement.style.overflow = "visible";
  document.body.style.overflow = "visible";
  measure();
  window.addEventListener("resize", measure);
});
onUnmounted(() => {
  document.documentElement.style.overflow = saved.html;
  document.body.style.overflow = saved.body;
  window.removeEventListener("resize", measure);
});
</script>

<template>
  <main class="page">
    <h1>底部測試</h1>
    <p>下面有五條，哪一條的<b>底邊貼到螢幕最底</b>？截圖給開發者。</p>
    <p v-if="sizes" class="nums">
      主畫面 App：{{ sizes.standalone ? "是" : "否" }}・螢幕 {{ sizes.screen }}・網頁 {{ sizes.inner }}・可見 {{ sizes.visual }}・安全區 上 {{ sizes.safeTop }} 下 {{ sizes.safeBottom }}<br />
      <span v-for="(v, k) in units" :key="k">{{ k }} = {{ v }}　</span>
    </p>
    <button class="btn" @click="measure">重新量</button>
    <div class="bar a">A<br />bottom 0</div>
    <div class="bar b" :style="{ bottom: `-${sizes?.gap ?? 0}px` }">B<br />往下 {{ sizes?.gap ?? 0 }}</div>
    <div class="bar c">C<br />100lvh</div>
    <div class="bar d" :style="{ top: `${screenTop}px` }">D<br />螢幕高</div>
    <div class="bar e">E<br />100vh</div>
  </main>
</template>

<style scoped>
.page { color: #fff; }
.nums { font-size: 13px; line-height: 1.6; }
.bar { position: fixed; width: 20%; height: 44px; color: #fff; font-size: 11px; font-weight: 700; text-align: center; line-height: 1.2; padding-top: 6px; box-sizing: border-box; z-index: 99; }
.a { left: 0; bottom: 0; background: #d33; }
.b { left: 20%; background: #e80; }
.c { left: 40%; top: calc(100lvh - 44px); background: #bb0; }
.d { left: 60%; background: #27c; }
.e { left: 80%; top: calc(100vh - 44px); background: #83c; }
</style>
