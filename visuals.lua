-- visuals

-- dialogue system by claude
-- spawns boxes at x,y (bottom-left)

dialogue={
    active=false,
    x=0,
    y=0,
    text="",
    lines={},
    width=0,
    height=0,
    char_idx=0,
    char_timer=0,
    char_speed=1, -- frames per char (lower=faster)
    char_width=4, -- pixels per char (4=normal, 3=small)
    line_height=6, -- pixels per line (6=normal, 5=small)
    max_width=100, -- max box width in pixels
    padding=4,
    border=1
}

function spawn_dialogue(x,y,text)
    dialogue.active=true
    dialogue.x=x
    dialogue.y=y
    dialogue.text=text
    dialogue.char_idx=0
    dialogue.char_timer=0
    -- pre-calculate word wrapping
    dialogue.lines=wrap_text(text,dialogue.max_width)
    -- calculate box dimensions
    dialogue.width=get_max_line_width(dialogue.lines)
    dialogue.height=#dialogue.lines*dialogue.line_height
end

function wrap_text(text,max_w)
    local lines={}
    local words=split_words(text)
    local line=""
    local line_w=0
    for word in all(words) do
        local word_w=#word*dialogue.char_width
        if line_w+word_w<=max_w then
            -- word fits on current line
            if line=="" then
                line=word
                line_w=word_w
            else
                line=line.." "..word
                line_w=line_w+dialogue.char_width+word_w
            end
        else
            -- need new line
            if line!="" then
                add(lines,line)
            end
            line=word
            line_w=word_w
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
        local w=#line*dialogue.char_width
        if w>max_w then
            max_w=w
        end
    end
    return max_w
end

function update_dialogue()
    if not dialogue.active then return end
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
end

function draw_dialogue()
    if not dialogue.active then return end
    local d=dialogue
    local p=d.padding
    local b=d.border
    -- calculate top-left corner
    -- y is bottom of box, so subtract height
    local bx=d.x
    local by=d.y-d.height-(p*2)-(b*2)
    local bw=d.width+(p*2)+(b*2)
    local bh=d.height+(p*2)+(b*2)
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
            -- use small font if char_width is 3
            if d.char_width==3 then
                print("\^w"..visible_text,tx,ty,7)
            else
                print(visible_text,tx,ty,7)
            end
        end
        chars_drawn+=#line
        ty+=d.line_height
        if chars_drawn>=d.char_idx then
            break
        end
    end
end

function close_dialogue()
    dialogue.active=false
end