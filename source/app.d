import vibe.vibe;
import std.file;
import linkdir;
import std.process;

int main(){
	auto settings = new HTTPServerSettings;
	settings.port = 8069;
	settings.bindAddresses = ["::1","127.0.0.1"];
	settings.sessionStore = new MemorySessionStore;
	auto router = new URLRouter;

	auto sql_sock = environment.get("PGSOCK","/run/postgresql/");
	router.registerWebInterface(new LinkDirWeb(sql_sock));
	router.get("*",serveStaticFiles("public/"));
	router.rebuild();
	auto l = listenHTTP(settings,router);
	scope(exit) l.stopListening();
	runApplication();
	return 0;
}