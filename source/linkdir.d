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

class LinkDirWeb{
	private LinkTree tree;
	private Connection db;
	this(){
		tree = new LinkTree();
		db = tree.getDB();
	}
	@path("/")
	void getIndex(){
		auto result = db.exec("select * from links;");
		auto tagtree = tree.list_tags(0).renderHTML();
		/*foreach (row; result)
		{
			writeln(row["name"].as!string,"\t",row["url"].as!string);
		}*/
		
		render!("index.dt",result,tagtree);
	}
	@path("/tag/*")
	void getTag(scope HTTPServerRequest req,scope HTTPServerResponse res){
		res.writeBody("Got url path: "~ req.requestPath.toString());
	}
	@path("/id/:id")
	void getTagById(scope HTTPServerRequest req,scope HTTPServerResponse res){
		auto id = req.params["id"].to!int;
		auto ttree=tree.list_tags(id);
		auto tagsub = ttree.get_subcategories();
		auto tagtree = ttree.renderHTML();
		auto taglinks = tree.list_links(id);
		auto tagname = tree.get_tag_by_id(id).get(TagTree.Tag(0,"/",0)).name;
		render!("tag.dt",tagtree,taglinks,tagname,tagsub);
	}
	void getAddTag(int parent,string name){
		tree.add_tag(name,parent);
		redirect("/");
	}
	void getRmTag(int id){
		tree.remove_tag(id);
		redirect("/");
	}
	void getTagLink(int tag_id,int link_id){
		tree.tag_link(tag_id,link_id);
	}
	void postAddLink(scope HTTPServerRequest req,scope HTTPServerResponse res){
	
		string linkname = req.form.get("linkname","");
		string linkvalue = req.form.get("linkvalue","");
		
		if(linkname.length>0){
			if(linkvalue.length){
				auto link_id = tree.add_link(linkname,linkvalue);
				auto tags = req.form.getAll("tags");
				foreach (tag; tags){
					tree.tag_link(tag.to!int,link_id);
				}
			}else{
				db.execParams("delete from links where name=$1::text;",linkname);
			}	
		}
		
		
		
		res.redirect("/");
	}
	void getAddLink(){
		auto tagtree = tree.list_tags(0).renderHTML((t)=>"<input type='checkbox' name='tags' value='%d'/>".format(t.id));
		render!("add_link.dt",tagtree);
	}
	void getManageTags(){
		auto tagtree = tree.list_tags(0).renderHTML((t)=>"<input type='radio' name='tag' value='%d'/>".format(t.id));
		render!("manage_tags.dt",tagtree);
	}
	void postManageTags(string action,int tag=0,string name=""){
		if(action == "create" && name.length > 0){
			tree.add_tag(name,tag);
		}else if(action == "delete"){
			tree.remove_tag(tag);
		}
		redirect("/manage_tags");
	}

}