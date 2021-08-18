module login_manager;
import dpq.connection;
import std.digest.sha;
import std.array;
import std.stdio;
import std.string;
import vibe.vibe;
enum PermissionBits{
    READ = 1,
    EDIT_TAGS = 2,
    EDIT_LINKS = 4,

}
class LoginManager{
    private Connection db;
    private int login_id = 0;
    private const int superuser = -1;
    this(Connection conn){
        db = conn;
    }
    bool pwcheck(string username,string pass){
        login_id = login(username,pass);
        return  login_id !=  0;
    }
    int login(string user,string pwd){
        auto res = db.execParams("select id,hash from users where login = $1::varchar;",user);
        if(res.empty())
            return 0;
        int id = res[0]["id"].as!int.get();
        string dbhash = res[0]["hash"].as!string.get("");
        if(!dbhash.length)
            return 0;
        string salt = dbhash.split(':')[0];
        string pwhash = cast(string)(salt~":"~toHexString(sha512Of(salt~":"~pwd)).toLower());
        //writeln(pwhash);

        return  pwhash == dbhash?id:0;
    }
    bool hasPermission(int user,int tree,int action_bits){
        auto res = db.execParams("select permission_byte from permissions where tree_id = $1::int and user_id = $2::int;",tree,user);
        if(res.empty())
            return false;
        int perms = res[0][0].as!int.get();
        return (perms & action_bits) == action_bits || user == superuser;
    }
    void ensure_permission(scope HTTPServerRequest req,scope HTTPServerResponse res,int tree,int perm){
        enforceHTTP(check_permission(req,res,tree,perm),HTTPStatus.forbidden);
    }
    bool check_permission(scope HTTPServerRequest req,scope HTTPServerResponse res,int tree,int perm,bool performAuth=true){
        if(hasPermission(0,tree,perm))
            return true;
        auto auth = req.headers.get("Authorization","");
        if(!auth.length&&!performAuth)
            return hasPermission(0,tree,perm);
        performBasicAuth(req,res,"Link Dir Realm",&this.pwcheck);

        return hasPermission(login_id,tree,perm) ;
    }
    string getUsername(scope HTTPServerRequest req,scope HTTPServerResponse res){
         auto auth = req.headers.get("Authorization","");
        if(!auth.length)
            return "public";
        return performBasicAuth(req,res,"Link Dir Realm",&this.pwcheck);
    }

}
