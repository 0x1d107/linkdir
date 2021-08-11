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
		//auto result = db.exec("select * from links;");
		auto tagtree = tree.list_tags(0).renderHTML();
		/*foreach (row; result)
		{
			writeln(row["name"].as!string,"\t",row["url"].as!string);
		}*/
		auto tagsub = tree.list_tags(0).get_subcategories();
		
		render!("index.dt",tagsub,tagtree);
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
		render!("tag.dt",id,tagtree,taglinks,tagname,tagsub,tagparent,tagsummary);
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
	void getEditLink(int id=0){
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
	void getSearch(string search = ""){
		auto links = tree.search_links(search);
		auto tags = tree.search_tags(search);
		render!("search.dt",search,tags,links);
	}
	void getEditTag(int id=0){
		auto tag = tree.get_tag_by_id(id);
		if (tag.isNull()){
			redirect("/manage_tags");
			return;
		}else{
			render!("edit_tag.dt",tag);
		}

	}
	void postEditTag(int id,string summary ){
		tree.update_tag(id,summary);
		redirect("/id/"~id.to!string);
	}

}