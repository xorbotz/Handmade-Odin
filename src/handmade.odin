package main
//Update the gameWindow needs - input, bitmapbuffer to use, sound buffer to use, timing maybe
game_offscreen_buffer::struct{
    memory:rawptr,
    Height,Width, Pitch:i32,
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

game_output_sound_buffer::struct{
    SamplesPerSecond:u32,
    SampleCount:u32,
    SampleOut:[^]i32
}

GameOutputSound::proc(SoundBuffer: ^game_output_sound_buffer){

    Soundlevel :i16=3000
    ToneHz:u32 = 256
    SquareWavePeriod:u32  = SoundBuffer.SamplesPerSecond/ToneHz
    for SampleIndex:u32= 0; SampleIndex<SoundBuffer.SampleCount;SampleIndex+=1{

        SampleValue:i16 = ((u32(SampleIndex)/cast(u32)SquareWavePeriod/2)%2)==0?Soundlevel:-1*Soundlevel

        temp:=cast(i32)SampleValue
        temp = temp<<16
        temp2:=i32(i32(SampleValue)&0b00000000000000001111111111111111)
        final: = temp|temp2
        SoundBuffer.SampleOut[SampleIndex] = final
        //SoundOutput.RunningSampleIndex+=1

    }
    /*for SampleIndex:w.DWORD = 0; SampleIndex<Region2SampleCount;SampleIndex+=1{

        SampleValue:i16 = ((SoundOutput.RunningSampleIndex/cast(u32)SoundOutput.SquareWavePeriod/2)%2)==0?SoundOutput.SoundLevel:-1*SoundOutput.SoundLevel
        temp:=cast(i32)SampleValue
        temp = temp<<16
        temp2:=i32(i32(SampleValue)&0b00000000000000001111111111111111)
        final: = temp|temp2
        SampleOut2[SampleIndex] = final
        SoundOutput.RunningSampleIndex+=1
    }*/

}
GameUpdateAndRender::proc(Buffer: ^game_offscreen_buffer, offsetX: i32, offsetY:i32, SoundBuffer: ^game_output_sound_buffer){
    //TODO Possibly implement the game to be told where in time to put sound
    GameOutputSound(SoundBuffer)
    RenderWeirdGradient(Buffer,offsetX,offsetY)
}

