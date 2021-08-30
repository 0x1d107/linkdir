module linkdir;
import vibe.vibe;
import dpq.connection;
import std;
import std.string;
import diet.html;
import std.format;
import std.conv;
import link_tree;
import tag_tree;
import login_manager;


class LinkDirWeb{
	private LinkTree tree;
	private Connection db;
	private LoginManager login_manager;

	this(string pgsql_sock_path="/run/postgresql/"){
		db = Connection("host="~pgsql_sock_path~" dbname=linkdir user=linkdir");
		tree = new LinkTree(db);
		
		login_manager=new LoginManager(db);
	}
	void getLogin(scope HTTPServerRequest req,scope HTTPServerResponse res){
		performBasicAuth(req,res,"Link Dir Realm",&login_manager.pwcheck);
		redirect("/");
	}
	@path("/")
	void getIndex(scope HTTPServerRequest req,scope HTTPServerResponse res){
		//auto result = db.exec("select * from links;");
		auto tagtree = tree.list_tags(0).renderHTML();
		/*foreach (row; result)
		{
			writeln(row["name"].as!string,"\t",row["url"].as!string);
		}*/
		auto tagsub = tree.list_tags(0).get_subcategories();
		auto username = login_manager.getUsername(req,res);
		render!("index.dt",tagsub,tagtree,username);
	}

	@path("/id/:id")
	void getTagById(scope HTTPServerRequest req,scope HTTPServerResponse res){
		auto id = req.params["id"].to!int;
		auto ttree=tree.list_tags(id);
		auto tagsub = ttree.get_subcategories();
		auto tagtree = ttree.renderHTML();
		auto taglinks = tree.list_links(id);
		auto tag = tree.get_tag_by_id(id).get(TagTree.Tag(0,"/",0,Nullable!int.init,Nullable!string.init));
		auto tagname = tag.name;
		auto tagparent = tag.parent;
		auto tagsummary = tag.summary;
		auto writeperm = login_manager.check_permission(req,res,tree.getId(),PermissionBits.EDIT_TAGS,false);
		auto linkperm = login_manager.check_permission(req,res,tree.getId(),PermissionBits.EDIT_LINKS,false);
		auto username = login_manager.getUsername(req,res);
		login_manager.ensure_permission(req,res,tree.getId(),PermissionBits.READ);
		render!("tag.dt",id,tagtree,taglinks,tagname,tagsub,tagparent,tagsummary,writeperm,linkperm,username);
	}
	void getAddTag(scope HTTPServerRequest req,scope HTTPServerResponse res,int parent,string name){
		login_manager.ensure_permission(req,res,tree.getId(),PermissionBits.EDIT_TAGS);
		tree.add_tag(name,parent);
		redirect("/");
	}
	void getRmTag(scope HTTPServerRequest req,scope HTTPServerResponse res,int id){
		login_manager.ensure_permission(req,res,tree.getId(),PermissionBits.EDIT_TAGS | PermissionBits.EDIT_LINKS);
		tree.remove_tag(id);
		redirect("/");
	}
	void getTagLink(scope HTTPServerRequest req,scope HTTPServerResponse res,int tag_id,int link_id){
		login_manager.ensure_permission(req,res,tree.getId(),PermissionBits.EDIT_TAGS | PermissionBits.EDIT_LINKS);
		tree.tag_link(tag_id,link_id);
	}
	void postAddLink(scope HTTPServerRequest req,scope HTTPServerResponse res){
		login_manager.ensure_permission(req,res,tree.getId(), PermissionBits.EDIT_LINKS);
		string linkname = req.form.get("linkname","");
		string linkvalue = req.form.get("linkvalue","");
		auto tags = req.form.getAll("tags");
		if(linkname.length>0 && !tags.empty()){
			if(linkvalue.length){
				auto link_id = tree.add_link(linkname,linkvalue);
				
				foreach (tag; tags){
					tree.tag_link(tag.to!int,link_id);
				}
			}	
		}
		
		
		
		res.redirect("/");
	}
	void getAddLink(scope HTTPServerRequest req,scope HTTPServerResponse res,){
		login_manager.ensure_permission(req,res,tree.getId(), PermissionBits.EDIT_LINKS);
		auto tagtree = tree.list_tags(0).renderHTML((t)=>"<input type='checkbox' name='tags' value='%d'/>".format(t.id));
		render!("add_link.dt",tagtree);
	}
	void getManageTags(scope HTTPServerRequest req,scope HTTPServerResponse res,){
		login_manager.ensure_permission(req,res,tree.getId(), PermissionBits.EDIT_TAGS);
		auto tagtree = tree.list_tags(0).renderHTML((t)=>"<input type='radio' name='tag' value='%d'/>".format(t.id));
		render!("manage_tags.dt",tagtree);
	}
	void postManageTags(scope HTTPServerRequest req,scope HTTPServerResponse res,string action,int tag=0,string name=""){
		login_manager.ensure_permission(req,res,tree.getId(), PermissionBits.EDIT_TAGS);
		if(action == "create" && name.length > 0){
			tree.add_tag(name,tag);
		}else if(action == "delete"){
			tree.remove_tag(tag);
		}
		redirect("/manage_tags");
	}
	void getEditLink(scope HTTPServerRequest req,scope HTTPServerResponse res,int id=0){
		login_manager.ensure_permission(req,res,tree.getId(), PermissionBits.EDIT_LINKS);
		auto link_nullable = tree.get_link_by_id(id);
		if(link_nullable.isNull()){
			redirect("/add_link");

		}else{
			auto link = link_nullable.get();
			auto rbtags = tree.get_link_tags(id);
			string checkbox(tag_tree.TagTree.Tag t){
				return "<input type='checkbox' name='tags' %s value='%d'/>".format(!rbtags.equalRange(t.id).empty?"checked":"",t.id);
			}
			auto tagtree = tree.list_tags(0).renderHTML((tag_tree.TagTree.Tag t)=>checkbox(t));
			render!("edit_link.dt",tagtree,link);
		}
	}
	void postEditLink(scope HTTPServerRequest req,scope HTTPServerResponse res,
					string action,int id,string name,string url,string summary=""){
		login_manager.ensure_permission(req,res,tree.getId(), PermissionBits.EDIT_LINKS);
		if(action == "edit"){
			tree.update_link(id,name,url,summary);

			auto tags = SList!(int)();
			foreach(tag;req.form.getAll("tags")){
				tags.insertFront(tag.to!int);
			}
			tree.set_link_tags(id,tags);
			redirect("/edit_link?id="~id.to!string);
		}else if(action == "delete"){
			tree.remove_link(id);
			redirect("/");
		}
		
	}
	void getSearch(scope HTTPServerRequest req,scope HTTPServerResponse res,string search = ""){
		login_manager.ensure_permission(req,res,tree.getId(), PermissionBits.READ);
		auto links = tree.search_links(search);
		auto tags = tree.search_tags(search);
		render!("search.dt",search,tags,links);
	}
	void getEditTag(scope HTTPServerRequest req,scope HTTPServerResponse res,int id=0){
		login_manager.ensure_permission(req,res,tree.getId(), PermissionBits.EDIT_TAGS);
		auto tag = tree.get_tag_by_id(id);
		if (tag.isNull()){
			redirect("/manage_tags");
			return;
		}else{
			render!("edit_tag.dt",tag);
		}

	}
	void postEditTag(scope HTTPServerRequest req,scope HTTPServerResponse res,int id,string summary ){
		login_manager.ensure_permission(req,res,tree.getId(), PermissionBits.EDIT_TAGS);
		tree.update_tag(id,summary);
		redirect("/id/"~id.to!string);
	}
	void getEditPermissions(scope HTTPServerRequest req,scope HTTPServerResponse res){
		login_manager.ensure_permission(req,res,tree.getId(),PermissionBits.EDIT_PERMISSIONS);
		auto users = login_manager.getUsers();
		render!("edit_permissions.dt",users);
	}
	void postEditPermissions(scope HTTPServerRequest req,scope HTTPServerResponse res,int id,string perms){
		login_manager.ensure_permission(req,res,tree.getId(),PermissionBits.EDIT_PERMISSIONS);
		int[int] perm_bytes;
		foreach(entry;perms.split){
			auto k = entry.split(':')[0].to!int;
			auto v = entry.split(':')[1].to!int;
			perm_bytes[k] = v;
		}
		login_manager.updatePermissions(id,perm_bytes);
		redirect("/edit_permissions");
		
	}
	void getDeleteUser(scope HTTPServerRequest req,scope HTTPServerResponse res,int id){
		login_manager.ensure_permission(req,res,tree.getId(),PermissionBits.EDIT_PERMISSIONS);
		login_manager.deleteUser(id);
		redirect("/edit_permissions");
	}
	void postCreateUser(scope HTTPServerRequest req,scope HTTPServerResponse res,string username,string password,string email=""){
		login_manager.ensure_permission(req,res,tree.getId(),PermissionBits.EDIT_PERMISSIONS);
		login_manager.createUser(username,password,email);
		redirect("/edit_permissions");
	}
}