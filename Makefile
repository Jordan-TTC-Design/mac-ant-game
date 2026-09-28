# 三份 compose 檔，每個 target 都明確帶 -f，不依賴 docker compose 的預設檔解析。
#
#   無後綴   docker-compose.yml        線上（一般）   資料庫卷 db_data
#   -dev     docker-compose_dev.yaml   本機試跑整套   資料庫卷 db_data_dev
#   -prod    docker-compose_prod.yml   線上（正式）   資料庫卷 db_data
#
# dev 用獨立的資料卷，誤切檔案不會動到線上資料；兩份線上檔共用同一卷，
# 在正式主機上互相切換不會遺失資料。設定放在 repo 最上層的 .env（照 .env.template）。

DEV  := -f docker-compose_dev.yaml
PROD := -f docker-compose_prod.yml
BASE := -f docker-compose.yml

# make invite n=3 days=14　｜　make admin email=you@example.com
n    ?= 1
email ?=
days ?= 14

.PHONY: up up-dev up-prod down down-dev down-prod reset-dev \
        restart restart-dev restart-prod logs logs-dev logs-prod \
        deploy deploy-dev deploy-prod ps ps-dev ps-prod \
        invite invite-dev invite-prod invites invites-prod admin admin-prod admins vapid \
        dump-db dump-db-dev dump-db-prod restore-db shell-server shell-server-dev shell-server-prod \
        shell-db shell-db-dev shell-db-prod check-env

check-env:
	@test -f .env || { echo "ERROR: 沒有 .env。請照 .env.template 複製一份再改（cp .env.template .env）。"; exit 1; }

up: check-env
	docker compose $(BASE) up -d

down:
	docker compose $(BASE) down

restart:
	docker compose $(BASE) restart server web

logs:
	docker compose $(BASE) logs -f server

ps:
	docker compose $(BASE) ps

deploy: check-env
	docker compose $(BASE) up -d --build && docker image prune -f

up-dev: check-env
	docker compose $(DEV) up -d

down-dev:
	docker compose $(DEV) down

# 砍掉本機試跑的資料庫 volume（帳號、便利貼全部清掉）。
reset-dev:
	@printf '⚠️  這會刪除本機試跑資料庫的所有資料，確定請輸入 yes：'; \
	read ans; [ "$$ans" = "yes" ] || { echo "已取消"; exit 1; }
	docker compose $(DEV) down -v
	docker compose $(DEV) up -d

restart-dev:
	docker compose $(DEV) restart server web

logs-dev:
	docker compose $(DEV) logs -f server

ps-dev:
	docker compose $(DEV) ps

deploy-dev: check-env
	docker compose $(DEV) up -d --build && docker image prune -f

up-prod: check-env
	docker compose $(PROD) up -d

down-prod:
	docker compose $(PROD) down

restart-prod:
	docker compose $(PROD) restart server web

logs-prod:
	docker compose $(PROD) logs -f server

ps-prod:
	docker compose $(PROD) ps

deploy-prod: check-env
	docker compose $(PROD) up -d --build --remove-orphans && docker image prune -f

# 邀請碼：只顯示這一次，請當場複製。make invite n=3 days=14
invite:
	docker compose $(BASE) exec server node --import tsx src/cli/invite.ts create --count $(n) --days $(days)

invite-dev:
	docker compose $(DEV) exec server node --import tsx src/cli/invite.ts create --count $(n) --days $(days)

invite-prod:
	docker compose $(PROD) exec server node --import tsx src/cli/invite.ts create --count $(n) --days $(days)

# 還能用／已使用／過期的邀請碼數量
invites:
	docker compose $(BASE) exec server node --import tsx src/cli/invite.ts list

invites-prod:
	docker compose $(PROD) exec server node --import tsx src/cli/invite.ts list

# 把一個帳號設成管理員（後台）：帳號要先註冊好。make admin email=you@example.com；make admins 列出管理員
admin:
	docker compose $(BASE) exec server node --import tsx src/cli/admin.ts grant $(email)

admin-prod:
	docker compose $(PROD) exec server node --import tsx src/cli/admin.ts grant $(email)

admins:
	docker compose $(BASE) exec server node --import tsx src/cli/admin.ts list

# 產生一組手機推播用的 VAPID 金鑰（貼進 .env，然後 make deploy）
vapid:
	docker compose $(BASE) run --rm --no-deps server node -e "const k=require('web-push').generateVAPIDKeys();console.log('VAPID_PUBLIC_KEY='+k.publicKey+'\nVAPID_PRIVATE_KEY='+k.privateKey)"

# 備份資料庫到 backups/（不進 git）
dump-db:
	@mkdir -p backups
	docker compose $(BASE) exec -T postgres pg_dump -U goblin -d goblin --clean --if-exists > backups/goblin-$$(date +%Y%m%d-%H%M%S).sql
	@ls -lh backups | tail -1

dump-db-dev:
	@mkdir -p backups
	docker compose $(DEV) exec -T postgres pg_dump -U goblin -d goblin --clean --if-exists > backups/goblin-dev-$$(date +%Y%m%d-%H%M%S).sql
	@ls -lh backups | tail -1

dump-db-prod:
	@mkdir -p backups
	docker compose $(PROD) exec -T postgres pg_dump -U goblin -d goblin --clean --if-exists > backups/goblin-$$(date +%Y%m%d-%H%M%S).sql
	@ls -lh backups | tail -1

# 用備份蓋回資料庫（線上一般）：make restore-db file=backups/goblin-XXXX.sql
restore-db:
	@test -n "$(file)" || { echo "用法：make restore-db file=backups/goblin-XXXX.sql"; exit 1; }
	@printf '⚠️  這會用 $(file) 蓋掉現在的資料庫，確定請輸入 yes：'; \
	read ans; [ "$$ans" = "yes" ] || { echo "已取消"; exit 1; }
	docker compose $(BASE) exec -T postgres psql -U goblin -d goblin < $(file)

shell-server:
	docker compose $(BASE) exec server sh

shell-server-dev:
	docker compose $(DEV) exec server sh

shell-server-prod:
	docker compose $(PROD) exec server sh

shell-db:
	docker compose $(BASE) exec postgres psql -U goblin -d goblin

shell-db-dev:
	docker compose $(DEV) exec postgres psql -U goblin -d goblin

shell-db-prod:
	docker compose $(PROD) exec postgres psql -U goblin -d goblin
