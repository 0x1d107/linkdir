import vibe.vibe;
import std.file;
import linkdir;

int main(){
	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	settings.bindAddresses = ["::1","127.0.0.1"];
	settings.sessionStore = new MemorySessionStore;
	auto router = new URLRouter;
	router.registerWebInterface(new LinkDirWeb);
	router.get("*",serveStaticFiles("public/"));
	router.rebuild();
	auto l = listenHTTP(settings,router);
	scope(exit) l.stopListening();
	runApplication();
	return 0;
}