module login_manager;
import dpq.connection;
import std.digest.sha;
import std.array;
import std.stdio;
import std.string;
import vibe.vibe;
import std.container;
import std.random;
import std.base64;
enum PermissionBits{
    READ = 1,
    EDIT_TAGS = 2,
    EDIT_LINKS = 4,
    EDIT_PERMISSIONS = 128,
}
struct User{
    string name;
    string email;
    int id;
    int[int] permissions;
}
class LoginManager{
    private Connection db;
    private int login_id = 0;
    private const int superuser = 1;
    this(Connection conn){
        db = conn;
    }
    bool pwcheck(string username,string pass){
        login_id = login(username,pass);
        return  login_id !=  0;
    }
    bool canDelete(int id){
        return id != superuser && id != 0;
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
            return user == superuser;
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
    
    SList!User getUsers(){
        auto res = db.execParams("select id,login,email from users;");
        SList!User users;
        foreach(user;res){
            auto id = user["id"].as!int.get();
            auto login = user["login"].as!string.get();
            auto email = user["email"].as!string.get("");
            auto perms_res = db.execParams("select tree_id,permission_byte from permissions where user_id = $1::int;",id);
            int[int] perms;
            foreach (perm_r; perms_res){
                int tree = perm_r["tree_id"].as!int.get(0);
                int permissions = perm_r["permission_byte"].as!int.get(0);
                perms[tree] = permissions;
            }
            users.insertFront(User(login,email,id,perms));
        }
        return users;
    }
    void updatePermissions(int user,int[int] perms){
        db.begin();
        db.execParams("delete from permissions where user_id = $1::int;",user);
        foreach(k,v;perms)
            db.execParams("insert into permissions(user_id,tree_id,permission_byte) values ($1::int,$2::int,$3::int);",user,k,v&0xff);
        db.commit();
    }
    int createUser(string username,string password,string email,int template_user = 0){
        ubyte[] salt_bytes;
        for(int i=0;i<128;i++){
            salt_bytes ~= [cast(ubyte)uniform(0,255u)];
        }
        string salt = Base64.encode(salt_bytes[]);
        db.begin();
        int id = db.execParams("insert into users(login,hash,email) values ($1::varchar,$2::varchar,$3::varchar) returning id;",username,
            cast(string)(salt~":"~toHexString(sha512Of(salt~":"~password)).toLower()),email)[0][0].as!int.get();
        db.execParams("insert into permissions(user_id,tree_id,permission_byte) select $1::int,tree_id,permission_byte from permissions where user_id = $2::int;",id,template_user);
        db.commit();
        return id;
    }
    void deleteUser(int id){
        if(canDelete(id))
            db.execParams("delete from users where id = $1::int;",id);
    }
}
