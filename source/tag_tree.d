module tag_tree;
import dpq.result;
import std.container;
import std.array;
import std.format;
import std.conv;
import std.functional;
import std.typecons;
import std;
struct Link{
    int id;
    string name;
    string url;
    Nullable!string summary;
}
class TagTree{
    struct Tag{
        int id;
        string name;
        int level;
        Nullable!int parent;
        Nullable!string summary;
        
    }
    
    private DList!Tag tags;
    private SList!Tag subcategories;
    private this(){

    }
    void add_tag(int id,string name, int lvl,int parent_id=0,string summary = ""){
        tags.insertBack(Tag(id,name,lvl,Nullable!(int)(parent_id),Nullable!(string)(summary)));
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
    private static string emptyCtrls(Tag t){
        return "";
    }
    string renderHTML(string delegate(Tag t) ctrls = toDelegate(&emptyCtrls)){
        auto str_builder = appender!string;
        int lvl = 1;
        int open_div = 0;
        int open_ul = 0;
        int open_li = 0;
        foreach(tag;tags){
            auto dlvl = tag.level - lvl;

            auto tag_html = "<span class='dir-name'><a href='%s'>%s</a></span>%s".format("/id/"~tag.id.to!string,tag.name,ctrls(tag));
            if(dlvl > 0){
                str_builder.put("<li>");
                open_li++;
            }else if(dlvl == 0){
                
                if(tag.level>1){
                    if(open_ul>0){
                        open_ul--;
                        str_builder.put("</ul>");
                    }
                    if(open_div>0){
                        open_div--;
                        str_builder.put("</div>");
                    }
                    str_builder.put("</li>");
                    str_builder.put("<li>");
                }
            }else if(dlvl < 0){
                if(open_ul>0){
                    open_ul--;
                    str_builder.put("</ul>");
                }
                if(open_div>0){
                        open_div--;
                        str_builder.put("</div>");
                }
                if(open_li>0){
                    open_li--;
                    str_builder.put("</li>");
                }

                for(int i=0;i< -dlvl;i++){
                    if(open_ul>0){
                        open_ul--;
                        str_builder.put("</ul>");
                    }
                    if(open_div>0){
                            open_div--;
                            str_builder.put("</div>");
                    }
                    if(open_li>0){
                        open_li--;
                        str_builder.put("</li>");
                    }
                }
                if(tag.level>1){
                    str_builder.put("<li>");
                    open_li++;
                }
            }
            str_builder.put("<div class='dir-node'>%s<ul class='dir-children'>".format(tag_html));
            open_div++;
            open_ul++;

            lvl = tag.level;
        }
        //writeln("divs:",open_div," ul:",open_ul," li:",open_li);
        
        while(open_ul>0||open_div>0||open_li>0){
            if(open_ul){
                str_builder.put("</ul>");
                open_ul--;
            }
            if(open_div){
                str_builder.put("</div>");
                open_div--;
            }
            if(open_li){
                str_builder.put("</li>");
                open_li--;
            }

        }
        return str_builder.data;
    }
}