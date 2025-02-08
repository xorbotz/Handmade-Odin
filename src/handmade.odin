package main
//Update the gameWindow needs - input, bitmapbuffer to use, sound buffer to use, timing maybe
game_offscreen_buffer::struct{
    memory:rawptr,
    Height,Width, Pitch:i32,
}

GameUpdateAndRender::proc(Buffer: ^game_offscreen_buffer, offsetX: i32, offsetY:i32){
    RenderWeirdGradient(Buffer,offsetX,offsetY)
}

RenderWeirdGradient::proc(Buffer: ^game_offscreen_buffer, offsetX,offsetY:i32){

    Rowz:[^]u8 = cast([^]u8)Buffer.memory
    //Rowz:^u8 = cast(^u8)Bitmapmemory
    Pitch: = Buffer.Pitch
    //Pitch:=4*width
    for y:i32=0; y< Buffer.Height;y+=1{
        Pixel:[^]u32 = cast([^]u32)Rowz
        for x:i32 = 0;x<Buffer.Width;x+=1{
            Blue : = cast(u8)(x+offsetX)
            Green: = cast(u8)(y+offsetY)

            final:u32= ((cast(u32)Green)<<8|cast(u32)Blue)
            Red:u32 = 0
            Pixel[(y*Pitch)+x]= final
        }
    //    Rowz = mem.ptr_offset(Rowz,Pitch)
    }

}