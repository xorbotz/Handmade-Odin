package main
//This file is for old windows code with pointer math. It will eventually all go away.
/*
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
}*/