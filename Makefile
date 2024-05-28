spa:
	SOMTHIGN=NOTHIGN npm run dev

server:
	find src | DELIVER_EMAIL=1 DATABASE_URL="postgres://postgres:postgres@127.0.0.1:5432/bear_gleam" entr -r gleam run server

server-nowatch:
	DELIVER_EMAIL=1 DATABASE_URL="postgres://postgres:postgres@127.0.0.1:5432/bear_gleam" gleam run server --worker --regions=us-east,us-west,india,europe,japan,austrailia

worker:
	gleam run worker --regions=us-east,us-west,india,europe,japan,austrailia

worker-watch:
	find src | entr -r gleam run worker --regions=us-east,us-west,india,europe,japan,austrailia

resetdb:
	 dropdb bear_gleam ; createdb bear_gleam ; make migrate

migrate:
	DATABASE_URL="postgres://postgres:postgres@127.0.0.1:5432/bear_gleam" gleam run migrate 

.PHONY: test
test:
	DATABASE_URL="postgres://postgres:postgres@127.0.0.1:5432/bear_gleam" gleam test
