update tags set 
    tag_left = case when tag_left >= (select left_tag from tags where id = $3::int )
                    then tag_left + 2 else tag_left end,
    tag_right= tag_right + 2
where tag_right >= (select right_tag from tags where id = $3::int) and tree_id = $2::int;
insert into tags(id,name,left_ tag,right_tag,level,tree_id)
          select id,$1::int, left_tag, right_tag ,level+1,$2::int where id = $3::int;
