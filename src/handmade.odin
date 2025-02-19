package main
//Update the gameWindow needs - input, bitmapbuffer to use, sound buffer to use, timing maybe
import "core:math"
import "core:fmt"

debug_mode:bool= true

game_memory::struct{
    isInit:bool,
    Permanentstoragesize:u64,
    PermanentStorage:rawptr,

    Transientstoragesize:u64,
    Transientstorage:rawptr
}
game_state::struct{
    offsetX:i32,
    offsetY:i32,
    ToneHz:u32,

}
game_button_state::struct{
    HalfTransitionCount:int,
    EndedDown:bool,
}
game_pad::struct{

    Up:game_button_state,
    Down:game_button_state,
    Left:game_button_state,
    Right:game_button_state,
    LShoulder:game_button_state,
    RShoulder:game_button_state,
}
Buttons:: union{
    [6]game_button_state,
    game_pad,
}

game_controller_input::struct{
    StartX:f32,
    MinX:f32,
    MaxX:f32,
    EndX:f32,

    StartY:f32,
    MinY:f32,
    MaxY:f32,
    EndY:f32,
    IsAnalgo:bool,
    gamepad:game_pad,
    padButtons: union{
        [6]game_button_state,
        game_pad,
        },


}
game_input::struct{
    Controllers:[4]game_controller_input
}
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
    SampleOut:[^]i32,
    ToneHz:u32
}

GameOutputSound::proc(SoundBuffer: ^game_output_sound_buffer,ToneHz:u32){

    Soundlevel :i16=1000
   // ToneHz:u32 = SoundBuffer.ToneHz
    SquareWavePeriod:u32  = 48000/ToneHz
    for SampleIndex:u32= 0; SampleIndex<SoundBuffer.SampleCount;SampleIndex+=1{

        SampleValue:i16 = ((u32(SampleIndex)/cast(u32)SquareWavePeriod/2)%2)==0?Soundlevel:-1*Soundlevel

        temp:=cast(i32)SampleValue
        temp = temp<<16
        temp2:=i32(i32(SampleValue)&0b00000000000000001111111111111111)
        final: = temp|temp2
        SoundBuffer.SampleOut[SampleIndex] = final
    }
}

GameUpdateAndRender::proc(Memory:^game_memory,Input:^game_input,Buffer: ^game_offscreen_buffer,  SoundBuffer: ^game_output_sound_buffer){
    //TODO Possibly implement the game to be told where in time to put sound
   Input0 :^game_controller_input = &Input.Controllers[0]
   GameState:^game_state = cast(^game_state)Memory.PermanentStorage
   if debug_mode{
   assert(size_of(GameState)<=Memory.Permanentstoragesize)
    }
   if !Memory.isInit{
       GameState.ToneHz = 256*4
       GameState.offsetY=0
       GameState.offsetX=0
       //TODO may be appropriate to do in platform layer
       Memory.isInit = true

   }

    if(Input0.IsAnalgo){
        //NOTE do analog stuff
        GameState.ToneHz=256+ u32(128.0*f32(Input0.EndY))
        GameState.offsetX +=i32(4.0*f32(Input0.EndX))
    }
    else{
        //Note do didigtal stuff
    }

    switch buttons in Input0.padButtons{
        case game_pad:
           if buttons.Down.EndedDown{
               GameState.offsetY+=1
           }
        case [6]game_button_state:
            if buttons[0].EndedDown{
                GameState.offsetY+=1
            }

    }

    GameOutputSound(SoundBuffer,GameState.ToneHz)
    RenderWeirdGradient(Buffer,GameState.offsetX,GameState.offsetY)
}

