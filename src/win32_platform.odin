package main

import "core:fmt"
import w "core:sys/windows"
import "base:runtime"
import vmem "core:mem/virtual"
import "core:mem"
import "core:dynlib"
import "core:math"
import "core:strings"
import "core:strconv"
import "base:intrinsics"

//import dx "vendor:directx"
/*TODO
    Save Game Locations
    Hand on exe file
    Asset loading path
    Threading
    Raw input (Support for multiple keyboards...)
    Sleep and timeBegin (don't kill a pc battery)
    Clip Cursor
    Fullscreen
    WM_SetupCursor
    WM_Activeapp
    BlitSpeed improvements
    Hardware Accel (OpenGL/Direct3d...)
    GetKeyboardLayout (Other Keyboards)
*/
//TODO MAKE THESE NOT GLOBAL
running := true
Global_Back_Buffer:=win32_offscreen_buffer{}
GlobalSecondaryBuffer: ^IDirectSoundBuffer

ProcessDidigtalButton::proc(XInputButtonState: w.XINPUT_GAMEPAD_BUTTON,OldState:^game_button_state,NewState:^game_button_state, ButtonBit:w.XINPUT_GAMEPAD_BUTTON_BIT){
    NewState.HalfTransitionCount = OldState.EndedDown !=NewState.EndedDown?1:0
//    NewState.EndedDown =(XInputButtonState & ButtonBit) == ButtonBit
    NewState.EndedDown  =XInputButtonState& w.XINPUT_GAMEPAD_BUTTON{ButtonBit} == w.XINPUT_GAMEPAD_BUTTON{ButtonBit}
}
win32_window_dimensions::struct{
    width:i32,
    height:i32,
}

win32_sound_output::struct{
    SamplesPerSecond:u32,
    Hz:int,
    RunningSampleIndex:u32,
    SquareWaveCounter:int,
    SquareWavePeriod:int,
    BytesPerSample: u32,
    SecondaryBufferSize :u32,
    SoundLevel:i16,
    LatencySampleCount:u32,
}

win32ClearBuffer::proc(SoundOutput: ^win32_sound_output){
    Region1: w.VOID
    Region1Size: w.DWORD
    Region2: w.VOID
    Region2Size: w.DWORD

    lock_ok: = GlobalSecondaryBuffer->Lock(0,SoundOutput.SecondaryBufferSize,
    &Region1,&Region1Size,
    &Region2, &Region2Size, 0)
    if lock_ok < 0 {
    // fmt.eprintf("Error in Lock: 0x%X\n",u32(u64(lock_ok) & 0x0000_0000_FFFF_FFFF))
    //  return
    }else{
        temp:[^]i8 = cast([^]i8)Region1
        temp2:[^]i8 = cast([^]i8)Region2
        DestSample :[^]i32 = cast([^]i32)temp
        DestSample2 :[^]i32 = cast([^]i32)temp2

        for ByteIndex:w.DWORD =0;ByteIndex<Region1Size;ByteIndex+=1{
            temp[ByteIndex]=0
        }
        for ByteIndex:w.DWORD =0;ByteIndex<Region2Size;ByteIndex+=1{
            temp2[ByteIndex]=0
        }
    }
    ulock_ok:=GlobalSecondaryBuffer->Unlock(Region1,Region1Size,Region2,Region2Size)
    if ulock_ok < 0 {
        fmt.eprintf("Error in GetCurrentPosition: 0x%X\n",u32(u64(ulock_ok) & 0x0000_0000_FFFF_FFFF))
        return
    }

}
//Something here isn't quite right when extracting it to the game layer but i don't know what
win32FillSoundBuffer::proc(SoundOutput: ^win32_sound_output, SampleIndextoLock:w.DWORD, BytesToWrite: w.DWORD, SourceBuffer: ^game_output_sound_buffer){
    Region1: w.VOID
    Region1Size: w.DWORD
    Region2: w.VOID
    Region2Size: w.DWORD
 //   fmt.println(BytesToWrite)

    lock_ok: = GlobalSecondaryBuffer->Lock(SampleIndextoLock, BytesToWrite,
    &Region1,&Region1Size,
    &Region2, &Region2Size, 0)
    if lock_ok < 0 {
    // fmt.eprintf("Error in Lock: 0x%X\n",u32(u64(lock_ok) & 0x0000_0000_FFFF_FFFF))
    //  jreturn
    }

    // Each sample is 32 bit, 16 left and 16 right channel
        temp:[^]i16 = cast([^]i16)Region1
        temp2:[^]i16 = cast([^]i16)Region2
        DestSample :[^]i32 = cast([^]i32)temp
        DestSample2 :[^]i32 = cast([^]i32)temp2
        SourceSample:[^]i32 = SourceBuffer.SampleOut
        Region1SampleCount: w.DWORD = Region1Size/cast(u32)SoundOutput.BytesPerSample
        Region2SampleCount: w.DWORD = Region2Size/cast(u32)SoundOutput.BytesPerSample

        for SampleIndex:w.DWORD = 0; SampleIndex<Region1SampleCount;SampleIndex+=1{
            //SampleValue:i16 = ((SoundOutput.RunningSampleIndex/cast(u32)SoundOutput.SquareWavePeriod/2)%2)==0?SoundOutput.SoundLevel:-1*SoundOutput.SoundLevel
            //temp:=cast(i32)SampleValue
            //temp = temp<<16
            //temp2:=i32(i32(SampleValue)&0b00000000000000001111111111111111)
            //final: = temp|temp2
            SoundOutput.RunningSampleIndex+=1
               DestSample[SampleIndex] = SourceSample[SampleIndex]
            }

    for SampleIndex:w.DWORD = 0; SampleIndex<Region2SampleCount;SampleIndex+=1{
        //SampleValue:i16 = ((SoundOutput.RunningSampleIndex/cast(u32)SoundOutput.SquareWavePeriod/2)%2)==0?SoundOutput.SoundLevel:-1*SoundOutput.SoundLevel
        //temp:=cast(i32)SampleValue
        //temp = temp<<16
        //temp2:=i32(i32(SampleValue)&0b00000000000000001111111111111111)
        //final: = temp|temp2
        SoundOutput.RunningSampleIndex+=1
        DestSample2[SampleIndex] = SourceSample[SampleIndex+Region1SampleCount]
        }

    //        fmt.println("RunningSampleindex", SoundOutput.RunningSampleIndex)
        ulock_ok:=GlobalSecondaryBuffer->Unlock(Region1,Region1Size,Region2,Region2Size)
        if ulock_ok < 0 {
            fmt.eprintf("Error in GetCurrentPosition: 0x%X\n",u32(u64(ulock_ok) & 0x0000_0000_FFFF_FFFF))
            return
        }

}
InitDSound::proc(Window: w.HWND, SamplesPerSecond: u32, PrimaryBufferSize :u32, SecondaryBufferSize: u32){
    //TODO - REPLACE ALL OF THIS WITH MINIAUDIO. I DON't Have the time to do that yet but I think low level miniaudio is right
    lib, ok := dynlib.load_library("dsound.dll")
    assert(ok)
    sym, found := dynlib.symbol_address(lib, "DirectSoundCreate")
    assert(found)
    DirectSound: ^IDirectSound = {}
    DirectSoundCreate := cast(proc(lpGuid: ^w.GUID, ppDS: ^^IDirectSound, pUnkOuter: rawptr) -> w.HRESULT)sym
    ds_result := DirectSoundCreate(nil, &DirectSound, nil)
    if ds_result < 0 {
        fmt.eprintf("Error in DirectSoundCreate: 0x%X\n",u32(u64(ds_result) & 0x0000_0000_FFFF_FFFF))
        return
    }
    WaveFormat: WAVEFORMATEX={
        wFormatTag = WAVE_FORMAT_PCM,
        nChannels = 2,
        nSamplesPerSec   = cast(u32)SamplesPerSecond,
        wBitsPerSample = 16,
        nBlockAlign = (2*16)/8,
        nAvgBytesPerSec = cast(u32)(SamplesPerSecond*(2*16)/8),
        cbSize = 0,

    }
    if(Window!=nil){
        scl_res := DirectSound->SetCooperativeLevel(Window,DSSCL_PRIORITY )
        if scl_res < 0 {
            fmt.eprintf("Error in SetCooperativeLevel: 0x%X\n",u32(u64(scl_res) & 0x0000_0000_FFFF_FFFF))
        return
        }
 }
    BufferDescription : DSBUFFERDESC={
        dwSize = size_of(DSBUFFERDESC),
        dwFlags = DSBCAPS_PRIMARYBUFFER,
        //This causes an error
        //dwBufferBytes = PrimaryBufferSize,
    }
    PrimaryBuffer: ^IDirectSoundBuffer
    cb_res:=DirectSound->CreateSoundBuffer(&BufferDescription,&PrimaryBuffer,nil)
    if cb_res < 0 {
        fmt.eprintf("Error in SetCooperativeLevel: 0x%X\n",u32(u64(cb_res) & 0x0000_0000_FFFF_FFFF))
        return
    }

    sf_res:= PrimaryBuffer->SetFormat(&WaveFormat)
    if sf_res < 0 {
        fmt.eprintf("Error in SetCooperativeLevel: 0x%X\n",u32(u64(sf_res) & 0x0000_0000_FFFF_FFFF))
        return
    }

    SecondaryBufferDescription : DSBUFFERDESC={
        dwSize = size_of(DSBUFFERDESC),
        dwFlags = DSBCAPS_GETCURRENTPOSITION2,
        dwBufferBytes = SecondaryBufferSize,
        lpwfxFormat = &WaveFormat,
    }

    sb_err:= DirectSound -> CreateSoundBuffer(&SecondaryBufferDescription,&GlobalSecondaryBuffer,nil)

    if sb_err < 0 {
        fmt.eprintf("Error in Creating 2ndary buffrer: 0x%X\n",u32(u64(sb_err) & 0x0000_0000_FFFF_FFFF))
        return
    }
    else{
        fmt.eprint("2ndary buffer created successfully")
    }

}

GetWindowDimension::proc(Window:w.HWND)->win32_window_dimensions{
    Result:win32_window_dimensions

    ClientRect :w.RECT
    w.GetClientRect(Window,&ClientRect)
    Result.width = ClientRect.right - ClientRect.left
    Result.height= ClientRect.bottom - ClientRect.top
    return Result
}

win32_offscreen_buffer::struct{
    info:w.BITMAPINFO,
    infoadr:^w.BITMAPINFO,
    memory:w.VOID,
    Height,Width, Pitch:i32,
    bmArena: vmem.Arena,
    arena_err: vmem.Allocator_Error,//= vmem.arena_init_growing(&Global_Back_Buffer.bmArena)
    arena_alloc : mem.Allocator,//= vmem.arena_allocator(&Global_Back_Buffer.bmArena)l
}




CopyBufferToWindow:: proc (Buffer:^win32_offscreen_buffer,DevContext: w.HDC, WindowWidth:i32,WindowHeight:i32, x,y,width,height:i32){

    w.StretchDIBits(DevContext,
        0,0,WindowWidth,WindowHeight,
        0,0,Buffer.Width,Buffer.Height,
        Buffer.memory,Buffer.infoadr,w.DIB_RGB_COLORS,w.SRCCOPY)

}
ResizeDIBSection::proc (Buffer: ^win32_offscreen_buffer,width:i32, height:i32){

    //TODO Free DIBSection
    if(Buffer^.memory!=nil){
        //Saving this just in case I need windows Malloc
       // w.VirtualFree(Bitmapmemory,0,w.MEM_RELEASE)
        vmem.arena_destroy((&Buffer^.bmArena))

    }

    Buffer^.Height = height
    Buffer^.Width = width
    Buffer^.Pitch = width
    Buffer^.info.bmiHeader.biSize = size_of(Buffer^.info.bmiHeader)
    Buffer^.info.bmiHeader.biWidth = Buffer^.Width
    Buffer^.info.bmiHeader.biHeight = -Buffer^.Height
    Buffer^.info.bmiHeader.biPlanes = 1
    Buffer^.info.bmiHeader.biBitCount = 32
    Buffer^.info.bmiHeader.biCompression = w.BI_RGB
    Buffer^.info.bmiHeader.biSizeImage = 0
    Buffer^.info.bmiHeader.biXPelsPerMeter=0
    Buffer^.info.bmiHeader.biYPelsPerMeter = 0
    Buffer^.info.bmiHeader.biClrImportant = 0
    Buffer^.info.bmiHeader.biClrImportant = 0
    Buffer^.infoadr = &Buffer^.info

    Bitmapmemorysize:uint = uint(4*width*height)
    //Saving this in case I need to switch back to windows Malloc
    //Bitmapmemory = w.VirtualAlloc(nil,Bitmapmemorysize,w.MEM_COMMIT, w.PAGE_READWRITE)
   Buffer^.memory = make_multi_pointer([^]u8,Bitmapmemorysize,Global_Back_Buffer.arena_alloc)//&bmarena
}
wndproc:: proc "stdcall"( window: w.HWND, msg:w.UINT, wparam: w.WPARAM,lparam: w.LPARAM )->w.LRESULT{
    context = runtime.default_context()
    Result : w.LRESULT = 0

    switch(msg){
        case w.WM_SIZE:

        case w.WM_DESTROY:
            w.OutputDebugStringA("WM_DESTROY\n")
            running = false

        case w.WM_KEYUP, w.WM_KEYDOWN, w.WM_SYSKEYDOWN, w.WM_SYSKEYUP:
            VKCode:= wparam
            wasDown:bool = (lparam&(1<<30)!=0)
            isDown:bool  = lparam&(1<<31)==0
            //TODO NEED TO FIX the stickykeys?
        if isDown!=wasDown{
            if VKCode == 'W'{

            } else if VKCode == 'A'{

            } else if VKCode == 'S'{

            } else if VKCode == 'D'{

            }
            else if VKCode == 'Q'{

            }
            else if VKCode == 'E'{

            } else if VKCode ==w.VK_RIGHT{

            } else if VKCode ==w.VK_DOWN{

            } else if VKCode ==w.VK_LEFT{

            } else if VKCode ==w.VK_UP{

            } else if VKCode ==w.VK_ESCAPE{

                fmt.print("Escape: ")
                if(isDown){
                    fmt.print("is down")
                }

                if(wasDown){
                    fmt.print("was down")
                }
                fmt.print("\n")
            } else if VKCode ==w.VK_SPACE{

            }
            AltKeydown := lparam &(1<<29)
            if VKCode == w.VK_F4 && AltKeydown>0{
                running=false
            }
        }

        case w.WM_CLOSE:
            //TODO: change this with a message
            w.OutputDebugStringA("WM_CLOSE\n")
            running = false
            //w.PostQuitMessage(0)

        case w.WM_ACTIVATEAPP:
            w.OutputDebugStringA("WM_ACTivateApp\n")
        case w.WM_PAINT:
            painter: w.PAINTSTRUCT

            DevContext:w.HDC = w.BeginPaint(window,&painter)
            x:=painter.rcPaint.left
            y:=painter.rcPaint.top
            width := painter.rcPaint.right - painter.rcPaint.left
            height:= painter.rcPaint.bottom - painter.rcPaint.top

            Dimension := GetWindowDimension(window)
            CopyBufferToWindow(&Global_Back_Buffer,DevContext,Dimension.width,Dimension.height, x,y,width,height)

            //w.PatBlt(DevContext,painter.rcPaint.left, painter.rcPaint.top,width,height,color)
            w.EndPaint(window,&painter)
            //fmt.println(colorcount)
            //w.OutputDebugStringA(colorcount)
        case :
           Result = w.DefWindowProcW(window,msg,wparam,lparam)
//            w.OutputDebugStringA("WM_DEFAULT\n")


    }
    return Result
}


main :: proc() {
    Global_Back_Buffer.arena_err = vmem.arena_init_growing(&Global_Back_Buffer.bmArena)
    Global_Back_Buffer.arena_alloc = vmem.arena_allocator(&Global_Back_Buffer.bmArena)

    colorcount:^int = new(int)
    colorcount^ = 0
    instance:=w.HINSTANCE(w.GetModuleHandleW(nil))


    class_name:= w.L("HH Window")

    cls:= w.WNDCLASSW{
        //DO THESER MATTER? Yes - redraws the whole window whenever reZied
        style = w.CS_HREDRAW|w.CS_VREDRAW,
        lpfnWndProc = wndproc,
        hInstance = instance,
        lpszClassName = class_name,
    }
    PerfCounterFrequency : w.LARGE_INTEGER
    w.QueryPerformanceFrequency(&PerfCounterFrequency)
    class:=w.RegisterClassW(&cls)
    assert(class!=0, "calss iddn't register oh no")
    GameWindow:=w.CreateWindowExW(w.WS_EX_LEFT,cls.lpszClassName,w.L("Game WIndow DUde"),w.WS_OVERLAPPEDWINDOW|w.WS_VISIBLE,w.CW_USEDEFAULT,w.CW_USEDEFAULT,w.CW_USEDEFAULT,w.CW_USEDEFAULT,nil,nil,instance,nil)

    ResizeDIBSection(&Global_Back_Buffer,1200,700)

    fmt.println(GameWindow)
    fmt.println(cast(u16)w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.A})
    if (GameWindow!=nil){
        msg:w.MSG

        SoundOutput : win32_sound_output
        SoundOutput.SamplesPerSecond = 48000
        SoundOutput.Hz = 440
        SoundOutput.RunningSampleIndex=0
        SoundOutput.SquareWaveCounter = 0

        SoundOutput.SquareWavePeriod = 48000/SoundOutput.Hz
        SoundOutput.BytesPerSample = size_of(i16)*2
        SoundOutput.SecondaryBufferSize = SoundOutput.SamplesPerSecond*cast(u32)SoundOutput.BytesPerSample
        SoundOutput.SoundLevel = 1000
        SoundOutput.LatencySampleCount = SoundOutput.SamplesPerSecond/15


        InitDSound(GameWindow,SoundOutput.SamplesPerSecond,48000*size_of(i16)*2,48000*size_of(i16)*2)
        Temp2:^[48000]i32= new([48000]i32,Global_Back_Buffer.arena_alloc)
        TempS :[]i32 = make_slice([]i32,SoundOutput.SecondaryBufferSize,Global_Back_Buffer.arena_alloc)
        Samples:[^]i32
        Samples = raw_data(Temp2[:])


//        win32FillSoundBuffer(&SoundOutput,0,(SoundOutput.LatencySampleCount*SoundOutput.BytesPerSample),&SoundBuffer)
        win32ClearBuffer(&SoundOutput)
        GlobalSecondaryBuffer->Play(0,0,0x01)

         soundisPlaying := true

        LastCounter:w.LARGE_INTEGER
        w.QueryPerformanceCounter(&LastCounter)
        //TODO This probably can be replaced by newer code
        LastCycleCount := intrinsics.read_cycle_counter()
        Input:[2]game_input
        NewInput:^game_input = &Input[0]
        //NewInput.Controllers
        OldInput:^game_input=&Input[1]
        OldController:^ game_controller_input
        NewController:^ game_controller_input

        for running {

            for w.PeekMessageW(&msg,nil,0,0,w.PM_REMOVE){
            //TODO could add a quit case here!

                w.TranslateMessage(&msg)
                w.DispatchMessageW(&msg)

            }
           //TODO POSSIBLY POLL MORE OFTEN
            for ControllerIndex:w.DWORD = 0;ControllerIndex<w.XUSER_MAX_COUNT; ControllerIndex+=1{
                ControllerState:w.XINPUT_STATE
                //TODO - Only poll controllers when we know they are plugged in - you can do this with an HID flag
                OldController = &OldInput.Controllers[ControllerIndex]
                NewController= &NewInput.Controllers[ControllerIndex]

                if cast(u32)w.XInputGetState(cast(w.XUSER)ControllerIndex,&ControllerState)==w.ERROR_SUCCESS{
                    Pad:^w.XINPUT_GAMEPAD = &ControllerState.Gamepad

                    //I believe all of this is necessary to work with xInput and Bitmask
                    //I Know you can dereference Pad without ^ but I like doing it for clarity
                    Up :bool= Pad^.wButtons&w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_UP} == w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_UP}
                    Down :bool= Pad^.wButtons&w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_DOWN} == w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_DOWN}
                    Left :bool= Pad^.wButtons&w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_LEFT} == w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_LEFT}
                    Right :bool= Pad^.wButtons&w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_RIGHT} == w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.DPAD_RIGHT}
                    Start :bool= Pad^.wButtons&w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.START} == w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.START}
                    OldController:game_controller_input
                    NewController:game_controller_input
                    NCGP:game_pad
                    OCGP:game_pad
                    OldController.padButtons = OCGP
                    NewController.padButtons = NCGP

                     //A :bool= Pad^.wButtons&w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.A} == w.XINPUT_GAMEPAD_BUTTON{w.XINPUT_GAMEPAD_BUTTON_BIT.A}
                    if NCGPtoUse, ok:= NewController.padButtons.(game_pad);ok{
                        //Pleaes GIt don't be a turd

                        OCGPtoUse :=OldController.padButtons.(game_pad)
                    ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse.Down,&NCGPtoUse.Down,w.XINPUT_GAMEPAD_BUTTON_BIT.A)
                    ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse.Up,&NCGPtoUse.Up,w.XINPUT_GAMEPAD_BUTTON_BIT.B)
                    ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse.Right,&NCGPtoUse.Right,w.XINPUT_GAMEPAD_BUTTON_BIT.X)
                   ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse.Left,&NCGPtoUse.Left,w.XINPUT_GAMEPAD_BUTTON_BIT.Y)
                   ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse.LShoulder,&NCGPtoUse.LShoulder,w.XINPUT_GAMEPAD_BUTTON_BIT.LEFT_SHOULDER)
                   ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse.RShoulder,&NCGPtoUse.RShoulder,w.XINPUT_GAMEPAD_BUTTON_BIT.RIGHT_SHOULDER)
                    }
                    else{
                        NCGPtoUse2: = NewController.padButtons.([6]game_button_state)
                        OCGPtoUse :=OldController.padButtons.([6]game_button_state)
                        ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse[0],&NCGPtoUse2[0],w.XINPUT_GAMEPAD_BUTTON_BIT.A)
                        ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse[1],&NCGPtoUse2[1],w.XINPUT_GAMEPAD_BUTTON_BIT.B)
                        ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse[2],&NCGPtoUse2[2],w.XINPUT_GAMEPAD_BUTTON_BIT.X)
                        ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse[0],&NCGPtoUse2[0],w.XINPUT_GAMEPAD_BUTTON_BIT.Y)
                        ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse[0],&NCGPtoUse2[0],w.XINPUT_GAMEPAD_BUTTON_BIT.LEFT_SHOULDER)
                        ProcessDidigtalButton(Pad^.wButtons,&OCGPtoUse[0],&NCGPtoUse2[0],w.XINPUT_GAMEPAD_BUTTON_BIT.RIGHT_SHOULDER)
                    }
                    Stickx: i16 = Pad^.sThumbLX
                    Sticky: i16 = Pad^.sThumbLY
                    makefast:i32 = 1
                    x:f32
                    y:f32
                    if Stickx<0{
                        x = f32(Stickx)/32768.0
                    }
                    else{
                        x = f32(Stickx)/32767.0
                    }
                    if Sticky<0{
                        y = f32(Sticky)/32768.0
                    }
                    else{
                        y = f32(Sticky)/32767.0
                    }
                    //INVERT X
                    x=-x
                    NewController.StartX = OldController.EndX
                    NewController.StartY = OldController.EndY
                    NewController.MinX = x
                    NewController.MaxX = x
                    NewController.EndX=x

                    NewController.MinY = y
                    NewController.MaxY = y
                    NewController.EndY=y
                    NewController.IsAnalgo = true
                    fmt.println(x)
                    NewInput.Controllers[ControllerIndex] = NewController



                }
                else{
                    //TODO Controller not available
                }
                Vibration:w.XINPUT_VIBRATION
                Vibration.wRightMotorSpeed = 60000
                Vibration.wLeftMotorSpeed = 60000
                w.XInputSetState(cast(w.XUSER)0,&Vibration)
            }
            //TEMP CODE TO PUT THE BUFFER ON THE STACK - TODO Replace
            PlayerCursor: w.DWORD
            WriteCursor: w.DWORD
            SampleIndextoLock: w.DWORD
            WritePointer: w.DWORD=0
            BytesToWrite :w.DWORD=0
            SoundisValid:bool=false


            gp_ok:= GlobalSecondaryBuffer->GetCurrentPosition(&PlayerCursor, &WriteCursor)

            if gp_ok < 0 {
                fmt.eprintf("Error in GetCurrentPosition: 0x%X\n",u32(u64(gp_ok) & 0x0000_0000_FFFF_FFFF))
                return
            }

                SampleIndextoLock  = (SoundOutput.RunningSampleIndex*cast(u32)SoundOutput.BytesPerSample)%SoundOutput.SecondaryBufferSize
                TargerCursor:=(PlayerCursor+(SoundOutput.LatencySampleCount*SoundOutput.BytesPerSample))%SoundOutput.SecondaryBufferSize
            if SampleIndextoLock>TargerCursor{
                    fmt.println("here")
                    BytesToWrite = SoundOutput.SecondaryBufferSize-SampleIndextoLock
                    BytesToWrite +=TargerCursor
                } else{
                    BytesToWrite = TargerCursor - SampleIndextoLock

                }
                SoundisValid=true


            SoundBuffer :game_output_sound_buffer
            SoundBuffer.SamplesPerSecond = SoundOutput.SamplesPerSecond
            SoundBuffer.SampleCount = BytesToWrite/SoundOutput.BytesPerSample
            SoundBuffer.SampleOut = Samples
            SoundBuffer.ToneHz =440*2

            Buffer:game_offscreen_buffer
            Buffer.memory = Global_Back_Buffer.memory
            Buffer.Width = Global_Back_Buffer.Width
            Buffer.Height = Global_Back_Buffer.Height
            Buffer.Pitch = Global_Back_Buffer.Pitch

            if SoundisValid{
                win32FillSoundBuffer(&SoundOutput,SampleIndextoLock,BytesToWrite, &SoundBuffer)
            }

            GameUpdateAndRender(NewInput,&Buffer, &SoundBuffer)

//           if(!soundisPlaying){

 //               GlobalSecondaryBuffer->Play(0,0,0x01)
  //              soundisPlaying = true
   //         }

            DevContext:w.HDC = w.GetDC(GameWindow)
            Dimension := GetWindowDimension(GameWindow)
            CopyBufferToWindow(&Global_Back_Buffer,DevContext,Dimension.width,Dimension.height, 0,0,Dimension.width,Dimension.height)
            w.ReleaseDC(GameWindow,DevContext)


            EndCycleCount:= intrinsics.read_cycle_counter()
            CycleElapsed:=EndCycleCount - LastCycleCount
            EndCounter : w.LARGE_INTEGER
            w.QueryPerformanceCounter(&EndCounter)
            CounterElapsed: = EndCounter-LastCounter
            Time:=1000*CounterElapsed/PerfCounterFrequency
           //TODO remove debug code
            temp2:[4]byte
            temp3:[4]byte
            MCPF:= strconv.itoa(temp3[:],(int(CycleElapsed)/(1000*1000)))
            temp: = strings.concatenate({"Mili/Fram ",strconv.itoa(temp2[:],int(Time)),"CyclesElapsed(10^6): ",MCPF,"\n"})
            if Time>10{
            w.OutputDebugStringA(strings.clone_to_cstring(temp,context.temp_allocator))//"Counter Elapsed: ",CounterElapsed," PerfCountF ", PerfCounterFrequency,"This took ",Time," miliSeconds")
            }
            LastCounter = EndCounter
            LastCycleCount = EndCycleCount
           //TODO Can write a little func to do this so you just pingong back and forth
            Temp :^game_input = NewInput
            NewInput = OldInput
            OldInput = Temp
    }
 }
    else{
        fmt.println("we did not create the window!")
    }
    }
//    w.MessageBoxW(nil,w.L("This is a test"), w.L("Lol"),w.MB_OK|w.MB_ICONINFORMATION)



