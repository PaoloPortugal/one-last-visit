-- visuals

-- message system from my old game wumpus world, by claude

messages={}

function add_message(text)
-- adds a new message to the notification system
	add(messages, {
		text = text,
		time = 150 -- 5 seconds at 30fps = 150 frames
	})
end

function update_messages()
-- updates message timers and removes expired ones
	for i = #messages, 1, -1 do
		messages[i].time -= 1
		if messages[i].time <= 0 then
			deli(messages, i)
		end
	end
end

function draw_messages()
	-- draws all active messages stacked from bottom-left upwards
	local y = 126 -- start near bottom

	for i = #messages, 1, -1 do
		local msg = messages[i]
		local txt = msg.text
		local txt_width = #txt * 4 + 4
		local x = 2 -- left-aligned

		-- background box
		rectfill(x, y - 8, x + txt_width, y, 0)

		-- text
		print(txt, x + 2, y - 6, 7)

		-- move up for next message
		y -= 10
	end
end

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
    max_width=75, -- max box width in pixels
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
    -- pre-calculate word wrapping without hyphenation
    local all_lines=wrap_text_no_hyphen(dialogue.text,dialogue.max_width)
    
    -- if more than 3 lines, split into multiple dialogues
    if #all_lines > 3 then
        -- take first 3 lines for current dialogue
        dialogue.lines={}
        for i=1,3 do
            add(dialogue.lines,all_lines[i])
        end
        
        -- reconstruct remaining text from remaining lines
        local remaining_text=""
        for i=4,#all_lines do
            if remaining_text!="" then
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

function wrap_text_no_hyphen(text,max_w)
    local lines={}
    local words=split_words(text)
    local line=""
    local line_w=0
    
    for word in all(words) do
        local word_w=#word*4
        
        if line=="" then
            -- first word on line, always add it
            line=word
            line_w=word_w
        elseif line_w+4+word_w<=max_w then
            -- word fits on current line with space
            line=line.." "..word
            line_w=line_w+4+word_w
        else
            -- word doesn't fit, start new line
            add(lines,line)
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
    if btnp(🅾️) then -- z button
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

-- fade system by claude
function start_fade()
    fade_state = 1
    fade_timer = 0
end

function update_fade()
    if fade_state == 0 then return end
    
    fade_timer += 1
    
    if fade_state == 1 then
        -- fading to white
        if fade_timer >= fade_duration then
            fade_state = 2
            fade_timer = 0
        end
    elseif fade_state == 2 then
        -- stay white
        if fade_timer >= white_duration then
            fade_state = 3
            fade_timer = 0
        end
    elseif fade_state == 3 then
        -- fade back to normal
        if fade_timer >= fade_duration then
            fade_state = 0
            fade_timer = 0
        end
    end
end

function draw_fade()
    if fade_state == 0 then return end
    
    local amt = 0
    
    if fade_state == 1 then
        amt = fade_timer / fade_duration
    elseif fade_state == 2 then
        amt = 1
    elseif fade_state == 3 then
        amt = 1 - (fade_timer / fade_duration)
    end
    
    -- apply white overlay
    if amt > 0 then
        for i=0,15 do
            local c = i
            if amt >= 0.8 then c = 7
            elseif amt >= 0.6 then c = min(c+2,7)
            elseif amt >= 0.4 then c = min(c+1,7)
            elseif amt >= 0.2 then 
                if c < 6 then c = min(c+1,7) end
            end
            pal(i,c)
        end
    end
end

function draw_base_map(timeshift)
    pal(15,0)
    local x0=timeshift and 61 or 0
    local x1=timeshift and 120 or 59
    local y0=0
    local y1=31
    
    for x=x0,x1 do
        for y=y0,y1 do
            local tile=mget(x,y)
            spr(tile,x*8,y*8)
        end
    end

    pal()
end

function draw_map_over(timeshift)
    pal(15,0)
    local x0=timeshift and 61 or 0
    local x1=timeshift and 120 or 59
    local y0=0
    local y1=31

    for x=x0,x1 do
        for y=y0,y1 do
            local tile=mget(x,y)
            if fget(tile,1) then spr(tile,x*8,y*8) end
        end
    end
    pal()
end
