module tag_tree;
import dpq.result;
import std.container;
import std.array;
import std.format;
import std.conv;
struct Link{
    string name;
    string url;
}
class TagTree{
    struct Tag{
        int id;
        string name;
        int level;
        
    }
    
    private DList!Tag tags;
    private SList!Tag subcategories;
    private this(){

    }
    void add_tag(int id,string name, int lvl){
        tags.insertBack(Tag(id,name,lvl));
    }
    private void add_subcat(int id,string name, int lvl){
        subcategories.insertFront(Tag(id,name,lvl));
    }
    SList!Tag get_subcategories(){
        return this.subcategories;
    }
    static TagTree fromResult (Result res,int level=1){
        auto tree = new TagTree();
        foreach(row;res){
            tree.add_tag(row["id"].as!int.get(0),row["name"].as!string.get("").split('/').back(),row["level"].as!int.get(1));
            if(row["level"].as!int.get(1) == level+1){
                tree.add_subcat(row["id"].as!int.get(0),row["name"].as!string.get("").split('/').back(),row["level"].as!int.get(1));
            }
        }
        return tree;
    }
    string renderHTML(string function(Tag t) ctrls = (t)=>""){
        auto str_builder = appender!string;
        int lvl = 1;
        foreach(tag;tags){
            auto dlvl = tag.level - lvl;

            auto tag_html = "<span class='dir-name'><a href='%s'>%s</a></span>%s".format("/id/"~tag.id.to!string,tag.name,ctrls(tag));
            if(dlvl > 0){
                str_builder.put("<li>");
            }else if(dlvl == 0){
                
                if(tag.level>1){
                    str_builder.put("</ul></div></li>");
                    str_builder.put("<li>");
                }
            }else if(dlvl < 0){
                str_builder.put("</ul></div></li>");
                for(int i=0;i< -dlvl;i++){
                    str_builder.put("</ul></div></li>");
                }
                if(tag.level>1)
                    str_builder.put("<li>");
            }
             str_builder.put("<div class='dir-node'>%s<ul class='dir-children'>".format(tag_html));

            lvl = tag.level;
        }
        str_builder.put("</ul></div></li>");
        for(int i=1;i< lvl;i++){
            str_builder.put("</ul></div>");
            if(i<lvl-1)
                str_builder.put("</li>");
        }
        return str_builder.data;
    }
}