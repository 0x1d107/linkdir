module link_tree;
import dpq.connection;
import dpq.query;
import dpq.result;
import tag_tree;
import std.container;
import std.typecons;
/*
*    This class is responsible for getting link tree from the database. 
*/
class LinkTree{
    private Connection db;
    private int tree_id;
    private string SQL_ADD_LINK,  
    SQL_ADD_TAG_UPDATE,
    SQL_ADD_TAG_INSERT,
    SQL_TAG_SELECT_LR_BY_ID,
    SQL_ADD_ROOT_SELECT_MAX_RT,
    SQL_ADD_ROOT_INSERT,
    SQL_REMOVE_TAG_UPDATE,
    SQL_REMOVE_TAG_DELETE,
    SQL_REMOVE_TAG_CLEANUP_LINKS,
    SQL_REMOVE_LINK,
    SQL_TAG_LINK,
    SQL_UNTAG_LINK,
    SQL_LIST_TAGS_PARENT,
    SQL_LIST_TAGS_ALL,
    SQL_LIST_LINKS,
    SQL_TAG_BY_ID,
    SQL_TAG_BY_NAME,
    SQL_LINK_BY_ID,
    SQL_LIST_LINK_TAGS,
    SQL_LINK_CLEAR_TAGS,
    SQL_LINK_UPDATE,
    SQL_LINK_SEARCH,
    SQL_TAG_SEARCH;
    private Result exec(T...)(string q,T params){
        return this.db.execParams(q,params);
    }
    
    this(int tree_id=0){
        this.db = Connection("host=127.0.0.1 dbname=linkdir user=linkdir");
        this.tree_id = tree_id;
        this.SQL_ADD_LINK = "insert into links(name,url) values ($1::varchar,$2::varchar) returning id;";
        this.SQL_ADD_TAG_UPDATE = "update tags 
        set left_tag = case when left_tag > $3::int then left_tag + 2 else left_tag end,
           right_tag = right_tag + 2
    where right_tag >=  $4::int and tree_id = $2::int;
";
        this.SQL_ADD_TAG_INSERT = "insert into tags(name,left_tag,right_tag,level,tree_id,parent)
         select concat(name,'/',$1::varchar), right_tag-2, right_tag-1 ,level+1,$2::int,id from tags where id = $3::int;";
        this.SQL_TAG_SELECT_LR_BY_ID = "select left_tag,right_tag from tags where id = $1::int";
        this.SQL_ADD_ROOT_SELECT_MAX_RT = "select max(right_tag) from tags where tree_id = $1::int;";
        this.SQL_ADD_ROOT_INSERT = "insert into tags(name,left_tag,right_tag,level,tree_id) 
        values ($1::varchar,$2::int,$3::int,1,$4::int);";
        this.SQL_REMOVE_TAG_UPDATE = "update tags 
        set left_tag = case when left_tag > $1::int then left_tag - $2::int + $1::int - 1 else left_tag end,
           right_tag = right_tag - $2::int + $1::int - 1
        where right_tag > $2::int and tree_id = $3::int;";
        this.SQL_REMOVE_TAG_DELETE = "delete from tags where left_tag >= $1::int and right_tag <= $2::int and tree_id = $3::int;";
        this.SQL_REMOVE_TAG_CLEANUP_LINKS = "delete from links where id not in ( select link_id from tag_link );";
        this.SQL_REMOVE_LINK = "delete from links where id = $1::int;";
        this.SQL_LIST_TAGS_PARENT = "select * from tags where left_tag > $1::int and right_tag <= $2::int and tree_id = $3::int order by left_tag;";
        this.SQL_LIST_TAGS_ALL = "select * from tags where tree_id = $1::int order by left_tag;";
        this.SQL_TAG_LINK = "insert into tag_link(tag_id,link_id) values ($1::int,$2::int);";
        this.SQL_UNTAG_LINK = "delete from tag_link where tag_id = $1::int and link_id = $1::int;";
        this.SQL_LIST_LINKS = "
            select distinct on (link_id) link_id,links.name,url,links.summary from tag_link 
            inner join links on tag_link.link_id = links.id 
            inner join tags on tag_link.tag_id = tags.id
            where  left_tag >= $1::int 
            and right_tag <= $2::int 
            and tree_id = $3::int order by link_id;";
        this.SQL_TAG_BY_ID = "select * from tags where id = $1::int;";
        this.SQL_TAG_BY_NAME = "select * from tags where name = $1::int and tree_id = $2::int;";
        this.SQL_LINK_BY_ID = "select * from links where id = $1::int;";
        this.SQL_LIST_LINK_TAGS = "select tag_id from tag_link where link_id = $1::int;";
        this.SQL_LINK_CLEAR_TAGS = "delete from tag_link where link_id = $1::int;";
        this.SQL_LINK_UPDATE = "update links set name = $2::varchar,url= $3::varchar,summary=$4::varchar where id = $1::int;";
        this.SQL_LINK_SEARCH = "select * from links where ts @@ websearch_to_tsquery('english',$1::varchar);";
        this.SQL_TAG_SEARCH = "select * from tags where ts @@ websearch_to_tsquery('english',$1::varchar);";

    }
    Connection getDB(){
        return db;
    }
    int add_link(string name,string url){
        db.begin();
        auto res = exec(SQL_ADD_LINK,name,url);
        db.commit();
        return (res[0][0].as!int).get(0);
          
    }

    void add_tag(string name,int parent_id){
        db.begin();
        auto res = exec(SQL_TAG_SELECT_LR_BY_ID,parent_id);
        if(res.empty()){
            //Insert a root tag
            auto max_rt = exec(SQL_ADD_ROOT_SELECT_MAX_RT,tree_id);
            int left_tag,right_tag;
            if(max_rt.empty()){
                left_tag = 1;
                right_tag = 2;
            }else{
                left_tag = (max_rt[0][0].as!int).get(0)+1;
                right_tag = (max_rt[0][0].as!int).get(0)+2;
            }
            exec(SQL_ADD_ROOT_INSERT,name,left_tag,right_tag,tree_id);
            
        }else{
            //Insert a child 
            auto left_tag = (res[0][0].as!int).get();
            auto right_tag = (res[0][1].as!int).get();
            exec(SQL_ADD_TAG_UPDATE,name,tree_id,left_tag,right_tag);
            exec(SQL_ADD_TAG_INSERT,name,tree_id,parent_id);
        }
        db.commit();
        
    }
    void remove_tag(int id){
        db.begin();
        auto res = exec(SQL_TAG_SELECT_LR_BY_ID,id);
        if(!res.empty()){
            auto left_tag = (res[0][0].as!int).get(0);
            auto right_tag = (res[0][1].as!int).get(0);
            exec(SQL_REMOVE_TAG_DELETE,left_tag,right_tag,tree_id);
            exec(SQL_REMOVE_TAG_UPDATE,left_tag,right_tag,tree_id);
            exec(SQL_REMOVE_TAG_CLEANUP_LINKS);

        }
        db.commit();
    }
    void remove_link(int id){
        db.begin();
        exec(SQL_REMOVE_LINK,id);
        db.commit();
    }
    TagTree list_tags( int parent_tag){
        
        auto res = exec(SQL_TAG_BY_ID,parent_tag);
        auto level = 1;
        if(!res.empty()){
            auto left_tag = (res[0]["left_tag"].as!int).get(0);
            auto right_tag = (res[0]["right_tag"].as!int).get(0);
            level = (res[0]["level"].as!int).get(1);
            return TagTree.fromResult(exec(SQL_LIST_TAGS_PARENT,left_tag,right_tag,tree_id),level);
        }
        return TagTree.fromResult(exec(SQL_LIST_TAGS_ALL,tree_id),0);
    }
    SList!Link list_links( int parent_tag){
        auto list = SList!(Link)();
        auto lr_res = exec(SQL_TAG_SELECT_LR_BY_ID,parent_tag);
        auto left_tag = (lr_res[0]["left_tag"].as!int).get(0);
        auto right_tag = (lr_res[0]["right_tag"].as!int).get(0);
        if(lr_res.empty())
            return list;
        auto res = exec(SQL_LIST_LINKS,left_tag,right_tag,tree_id);
        
        foreach(row;res){
            list.insertFront(Link(row["link_id"].as!int.get(0),row["name"].as!string.get("db_error"),
            row["url"].as!string.get("https://example.com"),row["summary"].as!string));
        }
        return list;
    }
    Nullable!(TagTree.Tag) get_tag_by_id(int id){
        auto res = exec(SQL_TAG_BY_ID,id);
        if(res.empty())
            return Nullable!(TagTree.Tag)(TagTree.Tag(0,"",0)).init;
        return Nullable!(TagTree.Tag)(TagTree.Tag(id,res[0]["name"].as!string.get(),res[0]["level"].as!int.get(),
                res[0]["parent"].as!int,res[0]["summary"].as!string));
    }
    void tag_link(int tag,int link){
        exec(SQL_TAG_LINK,tag,link);
    }
    Nullable!Link get_link_by_id(int id){
        auto res = exec(SQL_LINK_BY_ID,id);
        if(res.empty())
            return Nullable!(Link)(Link(0,"","")).init;
        auto row = res[0];
        auto name = row["name"].as!string.get();
        auto url = row["url"].as!string.get();
        auto summary = row["summary"].as!string;
        return Nullable!(Link)(Link(id,name,url,summary));
    }
    RedBlackTree!int get_link_tags(int id){
        auto res = exec(SQL_LIST_LINK_TAGS,id);
        auto rbtree = new RedBlackTree!(int,"a < b",false);
        foreach(row;res){
            rbtree.stableInsert(row[0].as!int.get());
        }
        return rbtree;
    }

    void update_link(int id,string name,string url,string summary=""){
        exec(SQL_LINK_UPDATE,id,name,url,summary);
        
    }

    void set_link_tags(int id,SList!int tag_ids){
        db.begin();
        exec(SQL_LINK_CLEAR_TAGS,id);
        foreach (tag; tag_ids)
        {
            tag_link(tag,id);
        }
        db.commit();
    }
    SList!Link search_links(string query){
        auto list = SList!(Link)();
        auto result = exec(SQL_LINK_SEARCH,query);
        foreach(row;result){
            list.insertFront(Link(row["id"].as!int.get(0),row["name"].as!string.get("db_error"),
            row["url"].as!string.get("https://example.com"),row["summary"].as!string));
        }
        return list;
    }
    SList!(TagTree.Tag) search_tags(string query){
        auto list =  SList!(TagTree.Tag)();
        auto result = exec(SQL_TAG_SEARCH,query);
        foreach (row; result){
            list.insertFront(TagTree.Tag(row["id"].as!int.get(),row["name"].as!string.get(),row["level"].as!int.get(),
                row["parent"].as!int,row["summary"].as!string));
        }
        return list;
    }
}
