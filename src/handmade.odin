package main
//Update the gameWindow needs - input, bitmapbuffer to use, sound buffer to use, timing maybe
import "core:math"
import "core:fmt"

debug_mode:bool= true
Game_Mem:^game_memory

game_memory::struct{
    isInit:bool,
    Permanentstoragesize:u64,
    PermanentStorage:rawptr,

    Transientstoragesize:u64,
    Transientstorage:rawptr
}
thread_context::struct{
    temp:i32,
}
game_state::struct{
    offsetX:i32,
    offsetY:i32,
    Red:int,
    Green:int,
    Blue:int,
    ToneHz:u32,
    PlayerX:i32,
    PlayerY:i32,
    p1Jump:f32,
    p1JumpStart:i32,
    fhJump:bool,

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
    Action1:game_button_state,
    Action2:game_button_state,
    Action3:game_button_state,
    Action4:game_button_state,
    LShoulder:game_button_state,
    RShoulder:game_button_state,
    Start:game_button_state,
}
Buttons:: union{
    [9]game_button_state,
    game_pad,
}

game_controller_input::struct{
    isConnected:bool,
    IsAnalgo:bool,
    StickFramex:f32,
    StickFramey:f32,
    gamepad:game_pad,
    padButtons: union{
        [9]game_button_state,
        game_pad,
        },


}
game_input::struct{
    MouseButton:[2]game_button_state,
    MouseX:i32,
    MouseY: i32,
    Controllers:[5]game_controller_input
}
game_offscreen_buffer::struct{
    memory:rawptr,
    Height,Width, Pitch:i32,
}
RenderPlayer::proc(Buffer: ^game_offscreen_buffer, PlayerX:i32, PlayerY:i32){
    SpriteW:i32 = 10
    Color:u32  = 0xFFFFFFFF
    Left: i32= PlayerX
    Right:i32= Left+SpriteW
    Top:=PlayerY
    Bottom:i32= Top+SpriteW
    Rowz:[^]u8 = cast([^]u8)Buffer.memory
    //Rowz:^u8 = cast(^u8)Bitmapmemory
    Pitch: = Buffer.Pitch
    //Pitch:=4*width
    for y:i32=Top; y< Bottom;y+=1{
        Pixel:[^]u32 = cast([^]u32)Rowz
        for x:i32 = Left;x<=Right;x+=1{
            Pixel[(y*Pitch)+x]= Color
        }
    //    Rowz = mem.ptr_offset(Rowz,Pitch)
    }
}
RenderWeirdGradient::proc(Buffer: ^game_offscreen_buffer,GameState:^game_state){

    Rowz:[^]u8 = cast([^]u8)Buffer.memory
    //Rowz:^u8 = cast(^u8)Bitmapmemory
    Pitch: = Buffer.Pitch
    //Pitch:=4*width
    for y:i32=0; y< Buffer.Height;y+=1{
        Pixel:[^]u32 = cast([^]u32)Rowz
        for x:i32 = 0;x<Buffer.Width;x+=1{
            Blue : = u8(GameState.Blue)*cast(u8)(x+GameState.offsetX)
            Green: = u8(GameState.Green)*cast(u8)(y+GameState.offsetY)

            Red:u8 = u8(GameState.Red)*cast(u8)(y+GameState.offsetY)
           // (cast(u32)Red<<8|
            final:u32= (cast(u32)Red)<<16|(cast(u32)Green)<<8|cast(u32)Blue
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
    Soundlevel :i16=600
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

HandleInput::proc(GameState:^game_state,Input1:^game_controller_input, Height:i32, Width:i32){

    if(Input1.IsAnalgo){
        GameState.ToneHz=256+ u32(128.0*f32(Input1.StickFramey))
        GameState.PlayerX += i32(4.0*Input1.StickFramex)
        GameState.PlayerY -= i32(4.0*Input1.StickFramey +10.0*(GameState.p1Jump)*GameState.p1Jump)

    }
    else{
    //Note do didigtal stuff
        if GameState.p1Jump>0{
        GameState.PlayerY = i32(f32(GameState.PlayerY) -2.0*GameState.p1Jump*GameState.p1Jump)//*math.sin_f32(GameState.p1Jump*math.PI*.5))
        }
        else{

            GameState.PlayerY = i32(f32(GameState.PlayerY) +2.0*GameState.p1Jump*GameState.p1Jump)//*math.sin_f32(GameState.p1Jump*math.PI*.5))
        }
        //GameState.PlayerY = i32(f32(GameState.PlayerY))// +10.0*math.sin_f32(GameState.p1Jump))
    }
    if(GameState.PlayerY<GameState.p1JumpStart && GameState.p1Jump!=0){
    GameState.p1Jump -=.03
    }else if GameState.PlayerY>= GameState.p1JumpStart && GameState.fhJump == true{
        fmt.println("HEREHEREHRHEHEH:")
        GameState.p1Jump = 0
        GameState.PlayerY = GameState.p1JumpStart
        GameState.fhJump = false
    }

    //This is the digital part of the analog stick... can handle a bunch of ways
    switch buttons in Input1.padButtons{
    case game_pad:
        if buttons.Down.EndedDown{
            fmt.println("DOwn")
            GameState.offsetY-=1
            GameState.PlayerY +=5
        } if buttons.Left.EndedDown{
            fmt.println("left")
            GameState.offsetX+=1
            GameState.PlayerX -=5
        }  if buttons.Up.EndedDown{
            fmt.println("Up")
            GameState.offsetY+=1

            GameState.PlayerY -=5
        }  if buttons.Right.EndedDown{
            fmt.println("right")
            GameState.offsetX-=1

            GameState.PlayerX +=5
        }
        if buttons.Action1.EndedDown{
            fmt.println("Action1")
            GameState.Green=0
            GameState.Red=1
            GameState.Blue=1
            if GameState.p1Jump == 0{
            GameState.p1Jump = 1.0
                GameState.p1JumpStart = GameState.PlayerY
                GameState.fhJump = true
                }

        }

        if buttons.Action2.EndedDown{
            fmt.println("Action2")
            GameState.Green=0
            GameState.Red=0
            GameState.Blue=0
            GameState.p1Jump = 0
        }
        //push please

        if buttons.Action3.EndedDown{
            fmt.println("Action3")
            GameState.Green=1
            GameState.Red=2
            GameState.Blue=0
        }

        if buttons.Action4.EndedDown{
            fmt.println("Action4")
            GameState.Green=0
            GameState.Red=0
            GameState.Blue=1
        }
    if GameState.PlayerY<0{
        GameState.PlayerY =0
    }else if GameState.PlayerY+10>Height{
        GameState.PlayerY = Height-10
    }
        if GameState.PlayerX<0{
            GameState.PlayerX =0
        }else if GameState.PlayerX+10>Width{
            GameState.PlayerX = Width-10
        }

    case [9]game_button_state:
        if buttons[0].EndedDown{
            GameState.offsetY+=1
        }

    }
}

@(export)
game_hot_reloaded::proc(mem:^game_memory){
    Game_Mem = mem
}
@(export)
game_init::proc(PSs:u64, PS:rawptr, TSS:u64,TS:rawptr){
    Game_Mem = new(game_memory)
    Game_Mem.Permanentstoragesize=PSs
    Game_Mem.PermanentStorage = PS

    Game_Mem.Transientstoragesize = TSS
    Game_Mem.Transientstorage = TS
}
@(export)
game_sd::proc(){
    free(Game_Mem)
}
@(export)
game_mem_ptr::proc()->rawptr{
    return Game_Mem
}
@(export)
game_GameGetSoundSamples::proc( Thread: ^thread_context, Memory:^game_memory,SoundBuffer: ^game_output_sound_buffer)->bool{
    GameState:^game_state = cast(^game_state)Memory.PermanentStorage
    GameOutputSound(SoundBuffer,GameState.ToneHz)
    return true
}
@(export)
game_GameUpdateAndRender::proc(Thread: ^thread_context, Memory:^game_memory,Input:^game_input,Buffer: ^game_offscreen_buffer)->bool{
    //TODO Possibly implement the game to be told where in time to put sound
   Input0 :^game_controller_input = &Input.Controllers[0]
   Input1 :^game_controller_input = &Input.Controllers[1]
   GameState:^game_state = cast(^game_state)Memory.PermanentStorage
 // file_name:= "C:/Users/robotics/CLionProjects/Handmade-Odin/src/lol.txt"
   file_name:="src/lol.txt"
   file_name_w:="src/test1.txt"


   if !Memory.isInit{
       GameState.ToneHz = 256*4
       GameState.offsetY=0
       GameState.offsetX=0
       GameState.Blue=1
       GameState.Green=1
       //TODO This should almost certainly just be 1 multipointer but have to cross that bridge later
      // Bitmapdata,Bitmapmemory, BMSize:= ReadEntireFile(file_name)
      // PlatformWriteEntireFile(file_name_w,Bitmapdata,int(BMSize))
       Memory.isInit = true
       //DeleteFileData(Bitmapdata, Bitmapmemory)
       GameState.PlayerX = 100
       GameState.PlayerY =100

   }
   for &controller in Input.Controllers{
   HandleInput(GameState,&controller, Buffer.Height, Buffer.Width)
   }
    RenderWeirdGradient(Buffer,GameState)
    RenderPlayer(Buffer, GameState.PlayerX, GameState.PlayerY)
    return true
}

