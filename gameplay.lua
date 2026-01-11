-- gameplay
function make_pantry()
    local left=41
    local right=55
    local top=0
    local wall_start=10
    local bottom=15

    mset(left,top,58)
    for y=top+1,wall_start-1 do mset(left,y,57) end
    mset(left,wall_start,62)

    for x=left+1,left+2 do
        for y=wall_start,wall_start+5 do mset(x,y,68) end
    end

    for x=left+1,right-1 do
        mset(x,top,59)
        for y=top+1,top+3 do mset(x,y,31) end
        for y=top+4,top+5 do mset(x,y,70) end
        for y=top+5,wall_start-1 do mset(x,y,68) end
    end

    mset(right-2,wall_start,56)
    mset(right-1,wall_start,59)

    mset(right,top,60)
    for y=top+1,wall_start-1 do mset(right,y,57) end
    mset(right,wall_start,62)

end
