-- visuals

-- dialogue system by claude

dialogue={
    active=false,
    x=0,
    y=0,
    texts={}, -- table of dialogue strings
    current_idx=1, -- which dialogue we're on
    text="",
    lines={},
    width=0,
    height=0,
    char_idx=0,
    char_timer=0,
    char_speed=1, -- frames per char (lower=faster)
    max_width=80, -- max box width in pixels
    padding=4,
    border=1,
    input_delay=0 -- add this new field
}

function swap_case(text)
    local result=""
    for i=1,#text do
        local c=sub(text,i,i)
        local byte=ord(c)
        -- uppercase (65-90) -> lowercase (97-122)
        if byte>=65 and byte<=90 then
            result=result..chr(byte+32)
        -- lowercase (97-122) -> uppercase (65-90)
        elseif byte>=97 and byte<=122 then
            result=result..chr(byte-32)
        else
            result=result..c
        end
    end
    return result
end

function spawn_dialogue(x,y,texts)
    dialogue.active=true
    dialogue.x=x
    dialogue.y=y
    -- handle single string or table
    if type(texts)=="string" then
        dialogue.texts={swap_case(texts)}
    else
        local swapped={}
        for t in all(texts) do
            add(swapped,swap_case(t))
        end
        dialogue.texts=swapped
    end
    dialogue.current_idx=1
    dialogue.char_idx=0
    dialogue.char_timer=0
    dialogue.input_delay=5 -- add a 5 frame delay before accepting input
    load_current_dialogue()
end

function load_current_dialogue()
    dialogue.text=dialogue.texts[dialogue.current_idx]
    dialogue.char_idx=0
    dialogue.char_timer=0
    -- pre-calculate word wrapping with hyphenation
    local all_lines=wrap_text_with_hyphen(dialogue.text,dialogue.max_width)
    
    -- if more than 3 lines, split into multiple dialogues
    if #all_lines > 3 then
        -- take first 3 lines for current dialogue
        dialogue.lines={}
        for i=1,3 do
            add(dialogue.lines,all_lines[i])
        end
        
        -- check if last line ends with a hyphen (mid-word break)
        local last_line=dialogue.lines[3]
        local ends_with_hyphen=sub(last_line,#last_line)=="-"
        
        -- reconstruct remaining text
        local remaining_text=""
        
        if ends_with_hyphen then
            -- remove hyphen and get last character before it
            local line_without_hyphen=sub(last_line,1,#last_line-1)
            local last_char=sub(line_without_hyphen,#line_without_hyphen)
            -- update current line to end with hyphen
            dialogue.lines[3]=sub(line_without_hyphen,1,#line_without_hyphen-1).."-"
            -- start next text with hyphen + last char
            remaining_text="-"..last_char
        end
        
        for i=4,#all_lines do
            if remaining_text!="" and remaining_text!="-" then
                remaining_text=remaining_text.." "
            end
            remaining_text=remaining_text..all_lines[i]
        end
        
        -- insert remaining text as next dialogue
        local new_texts={}
        for i=1,dialogue.current_idx do
            add(new_texts,dialogue.texts[i])
        end
        add(new_texts,remaining_text)
        for i=dialogue.current_idx+1,#dialogue.texts do
            add(new_texts,dialogue.texts[i])
        end
        dialogue.texts=new_texts
    else
        dialogue.lines=all_lines
    end
    
    -- calculate box dimensions
    dialogue.width=get_max_line_width(dialogue.lines)
    dialogue.height=#dialogue.lines*6
end

function wrap_text_with_hyphen(text,max_w)
    local lines={}
    local words=split_words(text)
    local line=""
    local line_w=0
    for word in all(words) do
        local word_w=#word*4
        if line_w+word_w<=max_w then
            -- word fits on current line
            if line=="" then
                line=word
                line_w=word_w
            else
                line=line.." "..word
                line_w=line_w+4+word_w
            end
        else
            -- word doesn't fit - try to hyphenate
            if line=="" then
                -- word is longer than max_w, must break it
                local chars_that_fit=flr(max_w/4)-1 -- -1 for hyphen
                line=sub(word,1,chars_that_fit).."-"
                add(lines,line)
                -- put rest of word back for next iteration
                word=sub(word,chars_that_fit+1)
                line=""
                line_w=0
                -- continue processing the rest
                word_w=#word*4
                if word_w<=max_w then
                    line=word
                    line_w=word_w
                end
            else
                -- check if we can fit part of the word with hyphen
                local space_left=max_w-line_w-4 -- -4 for space
                local chars_that_fit=flr(space_left/4)-1 -- -1 for hyphen
                if chars_that_fit>=3 then
                    -- enough room to hyphenate
                    line=line.." "..sub(word,1,chars_that_fit).."-"
                    add(lines,line)
                    word=sub(word,chars_that_fit+1)
                    line=""
                    line_w=0
                    -- continue with rest of word
                    word_w=#word*4
                    if word_w<=max_w then
                        line=word
                        line_w=word_w
                    end
                else
                    -- not enough room, start new line
                    add(lines,line)
                    line=word
                    line_w=word_w
                end
            end
        end
    end
    -- add last line
    if line!="" then
        add(lines,line)
    end
    return lines
end

function split_words(text)
    local words={}
    local word=""
    for i=1,#text do
        local c=sub(text,i,i)
        if c==" " then
            if word!="" then
                add(words,word)
                word=""
            end
        else
            word=word..c
        end
    end
    if word!="" then
        add(words,word)
    end
    return words
end

function get_max_line_width(lines)
    local max_w=0
    for line in all(lines) do
        local w=#line*4
        if w>max_w then
            max_w=w
        end
    end
    return max_w
end

function is_dialogue_finished()
    -- count total chars in current dialogue
    local total_chars=0
    for line in all(dialogue.lines) do
        total_chars+=#line
    end
    return dialogue.char_idx>=total_chars
end

function update_dialogue()
    if not dialogue.active then return end
    
    -- countdown input delay
    if dialogue.input_delay > 0 then
        dialogue.input_delay -= 1
        -- still update character animation during delay
        local total_chars=0
        for line in all(dialogue.lines) do
            total_chars+=#line
        end
        if dialogue.char_idx<total_chars then
            dialogue.char_timer+=1
            if dialogue.char_timer>=dialogue.char_speed then
                dialogue.char_timer=0
                dialogue.char_idx+=1
            end
        end
        return -- don't process button input yet
    end
    
    -- count total chars in all lines
    local total_chars=0
    for line in all(dialogue.lines) do
        total_chars+=#line
    end
    -- animate character appearance
    if dialogue.char_idx<total_chars then
        dialogue.char_timer+=1
        if dialogue.char_timer>=dialogue.char_speed then
            dialogue.char_timer=0
            dialogue.char_idx+=1
        end
    end
    -- handle z button press
    if btnp(4) then -- z button
        if is_dialogue_finished() then
            -- move to next dialogue or close
            if dialogue.current_idx<#dialogue.texts then
                dialogue.current_idx+=1
                dialogue.input_delay=5 -- reset delay for next dialogue
                load_current_dialogue()
            else
                close_dialogue()
            end
        else
            -- skip to end of current dialogue
            dialogue.char_idx=total_chars
        end
    end
end

function draw_dialogue()
    if not dialogue.active then return end
    local d=dialogue
    local p=d.padding
    local b=d.border
    -- calculate box dimensions first (add space for button icon)
    local bw=d.width+(p*2)+(b*2)+8 -- +8 for button icon space
    local bh=d.height+(p*2)+(b*2)
    -- calculate top-left corner
    -- x is now center, so subtract half width
    -- y is bottom of box, so subtract height
    local bx=d.x-(bw/2)
    local by=d.y-bh
    -- draw border
    rectfill(bx-b,by-b,bx+bw+b,by+bh+b,7)
    -- draw black background
    rectfill(bx,by,bx+bw,by+bh,0)
    -- draw text with character animation
    local chars_drawn=0
    local tx=bx+p
    local ty=by+p
    for line in all(d.lines) do
        local visible_chars=min(#line,d.char_idx-chars_drawn)
        if visible_chars>0 then
            local visible_text=sub(line,1,visible_chars)
            print(visible_text,tx,ty,7)
        end
        chars_drawn+=#line
        ty+=6
        if chars_drawn>=d.char_idx then
            break
        end
    end
    
    -- draw button icon if dialogue is finished
    if is_dialogue_finished() then
        local icon_x=bx+bw-10 -- moved 4px more to the left (was -6)
        local icon_y=by+bh-6
        print("🅾️",icon_x,icon_y,7)
    end
end

function close_dialogue()
    dialogue.active=false
end

function draw_base_map(timeshift)
    pal(15,0)
    local x0=timeshift and 61 or 0
    local x1=timeshift and 120 or 59
    local y0=0
    local y1=46
    
    local width=x1-x0+1
    local height=y1-y0+1

    map(x0,y0,0,0,width,height)
    pal()
end

function draw_map_over(timeshift)
    pal(15,0)
    local x0=timeshift and 61 or 0
    local x1=timeshift and 120 or 59
    local y0=0
    local y1=46

    for x=x0,x1 do
        for y=y0,y1 do
            local tile=mget(x,y)
            if fget(tile,1) then spr(tile,x*8,y*8) end
        end
    end
    pal()
end
