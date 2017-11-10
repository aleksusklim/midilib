unit UMidiLib;

interface

uses
  UCachedList;

type
  TMidiHelper = class(TCachedListElem)
    class procedure Sure(Expression: Boolean);
    class function LittleWord(Big: Word): Word;
    class function LittleInteger(Big: Integer): Integer;
    class function VarLenRead(var Data: Pointer; out Value: Integer; var HaveSize, TotalSize: Integer): Boolean;
    class function VarLenWrite(var Data: Pointer; Value: Integer): Integer;
    class function ReadBytes(var ReadFrom: Pointer; SaveTo: Pointer; Size: Integer; var HaveSize, TotalSize: Integer): Boolean;
    class function WriteBytes(var SaveTo: Pointer; DataFrom: Pointer; Size: Integer): Integer;
    class function ParseMThd(var Memory: Pointer; out FormatType, TracksCount, TimeDivision: Integer; var HaveSize, TotalSize: Integer): Boolean;
    class function EncodeMThd(var Memory: Pointer; FormatType, TracksCount, TimeDivision: Integer): Integer;
    class function ParseMTrk(var Memory: Pointer; out DataLength: Integer; var HaveSize, TotalSize: Integer): Boolean;
    class function EncodeMTrk(var Memory: Pointer; DataLength: Integer): Integer;
    class function Recover(var Memory: Pointer; out MoreData: AnsiString; var HaveSize, TotalSize: Integer): Boolean;
  end;

  TMidiFile = class;

  TMidiTrack = class;

  TMidiEvent = class;

  FEventFilter = function(Event: TMidiEvent): Boolean;

  FTrackFilter = function(Track: TMidiTrack): Boolean;

  TMidiFile = class(TMidiHelper)
    constructor Create();
    destructor Destroy(); override;
    procedure Clear();
    procedure Assign(From: TMidiFile);
    function GetSize(): Integer;
    function ParseFrom(var LoadFrom: Pointer; var HaveSize, TotalSize: Integer): Boolean;
    function EncodeTo(var SaveTo: Pointer): Integer;
  public
    function Open(FileName: string): Boolean;
    function Save(FileName: string): Boolean;
    procedure Enum(FilterEvents: FEventFilter = nil; FilterTracks: FTrackFilter = nil);
    procedure Fix(FixNoteOnOff: Boolean);
    function CalcAbsolute(): Int64;
  public
    FormatType: Integer;
    TimeDivision: Integer;
    Tracks: TCachedList;
    UseRunning: Boolean;
  end;

  TMidiTrack = class(TMidiHelper)
    constructor Create(Owner: TMidiFile = nil; Index: Integer = -1);
    destructor Destroy(); override;
    procedure Clear();
    procedure Assign(From: TMidiTrack);
    function GetSize(): Integer;
    function ParseFrom(var LoadFrom: Pointer; var HaveSize, TotalSize: Integer): Boolean;
    function EncodeTo(var SaveTo: Pointer): Integer;
  public
    procedure RemoveEvent(Index: Integer);
    procedure Enum(FilterEvents: FEventFilter = nil);
    procedure Fix(FixNoteOnOff: Boolean);
    function CalcAbsolute(): Int64;
  public
    OwnerMidi: TMidiFile;
    OwnerIndex: Integer;
    Events: TCachedList;
  end;

  TMidiEvent = class(TMidiHelper)
    constructor Create(Owner: TMidiTrack = nil; Index: Integer = -1);
    destructor Destroy(); override;
    procedure Clear();
    procedure Assign(From: TMidiEvent);
    function GetSize(): Integer;
    function ParseFrom(var Previous: TMidiEvent; var LoadFrom: Pointer; var HaveSize, TotalSize: Integer): Boolean;
    function EncodeTo(Previous: TMidiEvent; var SaveTo: Pointer): Integer;
  public
    function IsRunning(): Boolean;
    function IsSystem(): Boolean;
    function IsSysEx(): Boolean;
    function IsSysCom(): Boolean;
    function IsSysRT(): Boolean;
    function IsUndef(out Bytes: Integer): Boolean;
    function IsMeta(): Boolean;
    function IsChannel(): Boolean;
    function TwoParams(): Boolean;
    function IsText(): Boolean;
    function IsNoteOff(): Boolean;
    function IsNoteOn(): Boolean;
    function IsControl(): Boolean;
    function IsProgram(): Boolean;
    function ConvertNoteOff(AsNoteOn: Boolean): TmidiEvent;
  public
    OwnerTrack: TMidiTrack;
    OwnerIndex: Integer;
    DeltaTime: Integer;
    EventType: Byte;
    Param1, Param2: Byte;
    MetaType: Byte;
    MoreData: AnsiString;
    AbsTime: Int64;
  end;

const
  ID_MThd = 1684558925;
  ID_MTrk = 1802654797;

type
  TRawMidiHeader = packed record
    Id: Integer;
    Size: Integer;
    FormatType, TracksCount, TimeDivision: Word;
  end;

  PRawMidiHeader = ^TRawMidiHeader;

type
  TRawMidiTrack = packed record
    Id: Integer;
    Size: Integer;
  end;

  PRawMidiTrack = ^TRawMidiTrack;

implementation

uses
  Classes, SysUtils, Math;

// TMidiHelper

class procedure TMidiHelper.Sure(Expression: Boolean);
begin
  if not Expression then
    Abort;
end;

class function TMidiHelper.LittleWord(Big: Word): Word;
begin
  Result := $ffff and ((Big shr 8) or (Big shl 8));
end;

class function TMidiHelper.LittleInteger(Big: Integer): Integer;
begin
  Result := (Big shl 24) or (Big shr 24) or ((Big shr 8) and $ff00) or ((Big shl 8) and $ff0000);
end;

class function TMidiHelper.VarLenRead(var Data: Pointer; out Value: Integer; var HaveSize, TotalSize: Integer): Boolean;
var
  Memory: PChar;
  Index: Integer;
  Current: Integer;
begin
  Result := False;
  Memory := Data;
  Value := 0;
  for Index := 0 to 4 do
  begin
    Dec(HaveSize);
    Inc(TotalSize);
    if (HaveSize < 0) or (Index = 4) then
      Exit;
    Current := Ord(Memory^);
    Inc(Memory);
    Value := (Value shl 7) or (Current and $7f);
    if (Current and $80) = 0 then
      Break;
  end;
  Data := Memory;
  Result := True;
end;

class function TMidiHelper.VarLenWrite(var Data: Pointer; Value: Integer): Integer;
var
  Temp: array[0..3] of Byte;
  Cnt: Integer;
  Memory: PChar;
begin
  Result := 0;
  if (Value < 0) or (Value > $0fffffff) then
    Exit;
  Cnt := 0;
  while True do
  begin
    Temp[Cnt] := (Value and 127) or 128;
    Value := Value shr 7;
    if Value = 0 then
      Break;
    Inc(Cnt);
  end;
  Result := Cnt + 1;
  Temp[0] := Temp[0] and 127;
  Memory := Data;
  repeat
    Memory^ := Chr(Temp[Cnt]);
    Inc(Memory);
    Dec(Cnt);
  until Cnt < 0;
  Data := Memory;
end;

class function TMidiHelper.ReadBytes(var ReadFrom: Pointer; SaveTo: Pointer; Size: Integer; var HaveSize, TotalSize: Integer): Boolean;
var
  Memory: PChar;
begin
  if HaveSize < Size then
  begin
    Result := False;
    Exit;
  end
  else
    Result := True;
  Memory := ReadFrom;
  Move(Memory^, SaveTo^, Size);
  Inc(Memory, Size);
  ReadFrom := Memory;
  Dec(HaveSize, Size);
  Inc(TotalSize, Size);
end;

class function TMidiHelper.WriteBytes(var SaveTo: Pointer; DataFrom: Pointer; Size: Integer): Integer;
var
  Memory: PChar;
begin
  Memory := SaveTo;
  Move(DataFrom^, Memory^, Size);
  Inc(Memory, Size);
  SaveTo := Memory;
  Result := Size;
end;

class function TMidiHelper.ParseMThd(var Memory: Pointer; out FormatType, TracksCount, TimeDivision: Integer; var HaveSize, TotalSize: Integer): Boolean;
var
  RawHeader: PRawMidiHeader;
  Size: Integer;
begin
  Result := False;
  RawHeader := Memory;
  if (HaveSize < SizeOf(TRawMidiHeader)) or (RawHeader.Id <> ID_MThd) then
    Exit;
  Size := LittleInteger(RawHeader.Size);
  FormatType := LittleWord(RawHeader.FormatType);
  TracksCount := LittleWord(RawHeader.TracksCount);
  TimeDivision := LittleWord(RawHeader.TimeDivision);
  Inc(TotalSize, Size);
  Dec(HaveSize, Size);
  Memory := PAnsiChar(Memory) + 4 + 4 + Size;
  Result := True;
end;

class function TMidiHelper.EncodeMThd(var Memory: Pointer; FormatType, TracksCount, TimeDivision: Integer): Integer;
var
  RawHeader: PRawMidiHeader;
begin
  RawHeader := Memory;
  RawHeader.Id := ID_MThd;
  RawHeader.Size := LittleInteger(6);
  RawHeader.FormatType := LittleWord(FormatType);
  RawHeader.TracksCount := LittleWord(TracksCount);
  RawHeader.TimeDivision := LittleWord(TimeDivision);
  Result := SizeOf(TRawMidiHeader);
  Memory := PAnsiChar(Memory) + Result;
end;

class function TMidiHelper.ParseMTrk(var Memory: Pointer; out DataLength: Integer; var HaveSize, TotalSize: Integer): Boolean;
var
  RawTrack: PRawMidiTrack;
begin
  Result := False;
  RawTrack := Memory;
  if (HaveSize < SizeOf(TRawMidiTrack)) or (RawTrack.Id <> ID_MTrk) then
    Exit;
  DataLength := LittleInteger(RawTrack.Size);
  Inc(TotalSize, SizeOf(TRawMidiTrack));
  Dec(HaveSize, SizeOf(TRawMidiTrack));
  Memory := PAnsiChar(Memory) + SizeOf(TRawMidiTrack);
  Result := True;
end;

class function TMidiHelper.EncodeMTrk(var Memory: Pointer; DataLength: Integer): Integer;
var
  RawTrack: PRawMidiTrack;
begin
  RawTrack := Memory;
  RawTrack.Id := ID_MTrk;
  RawTrack.Size := LittleInteger(DataLength);
  Result := SizeOf(TRawMidiTrack);
  Memory := PAnsiChar(Memory) + Result;
end;

class function TMidiHelper.Recover(var Memory: Pointer; out MoreData: AnsiString; var HaveSize, TotalSize: Integer): Boolean;
var
  Data: PAnsiChar;
begin
  Result := False;
  Data := Memory;
  MoreData := '';
  while HaveSize > 0 do
    if (Ord(Data^) and $80) <> 0 then
    begin
      Result := True;
      Break;
    end
    else
    begin
      Inc(Data);
      Dec(HaveSize);
      Inc(TotalSize);
    end;
  SetString(MoreData, PAnsiChar(Memory), Data - Memory);
  Memory := Data;
end;


// TMidiFile

constructor TMidiFile.Create();
begin
  Tracks := TCachedList.Create();
  Clear();
end;

destructor TMidiFile.Destroy();
begin
  Clear();
  Tracks.Free();
end;

procedure TMidiFile.Clear();
begin
  Tracks.Clear(True);
  FormatType := -1;
  TimeDivision := 0;
  UseRunning := False;
end;

procedure TMidiFile.Assign(From: TMidiFile);
var
  Index: Integer;
  Track: TMidiTrack;
begin
  Clear();
  for Index := 0 to From.Tracks.Count - 1 do
  begin
    Track := TMidiTrack.Create(Self, Index);
    Track.Assign(From.Tracks[Index] as TMidiTrack);
    Tracks.PushRight(Track);
  end;
  FormatType := From.FormatType;
  TimeDivision := From.TimeDivision;
end;

function TMidiFile.GetSize(): Integer;
var
  Index: Integer;
begin
  Result := SizeOf(TRawMidiHeader);
  for Index := 0 to Tracks.Count - 1 do
    Inc(Result, (Tracks[Index] as TMidiTrack).GetSize());
end;

function TMidiFile.ParseFrom(var LoadFrom: Pointer; var HaveSize, TotalSize: Integer): Boolean;
var
  Index, TracksCount: Integer;
  Track: TMidiTrack;
begin
  Clear();
  Track := nil;
  try
    Sure(ParseMThd(LoadFrom, FormatType, TracksCount, TimeDivision, HaveSize, TotalSize));
    Sure(FormatType in [0..2]);
    for Index := 0 to TracksCount - 1 do
    begin
      Track := TMidiTrack.Create(Self, Index);
      Sure(Track.ParseFrom(LoadFrom, HaveSize, TotalSize));
      Tracks.PushRight(Track);
    end;
    Result := True;
  except
    Track.Free();
    Clear();
    Result := False;
  end;
end;

function TMidiFile.EncodeTo(var SaveTo: Pointer): Integer;
var
  Index: Integer;
begin
  Result := EncodeMThd(SaveTo, FormatType, Tracks.Count, TimeDivision);
  for Index := 0 to Tracks.Count - 1 do
    Inc(Result, (Tracks[Index] as TMidiTrack).EncodeTo(SaveTo));
end;

function TMidiFile.Open(FileName: string): Boolean;
var
  Stream: TFileStream;
  Have, Total: Integer;
  Data, Memory: Pointer;
begin
  Clear();
  Total := 0;
  Stream := nil;
  Memory := nil;
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    Have := Stream.Size;
    GetMem(Memory, Have);
    Stream.ReadBuffer(Memory^, Have);
    Result := True;
  except
    Result := False;
  end;
  Stream.Free();
  Data := Memory;
  if Result then
    Result := ParseFrom(Data, Have, Total);
  if Memory <> nil then
    FreeMem(Memory);
end;

function TMidiFile.Save(FileName: string): Boolean;
var
  Stream: TFileStream;
  Data, Memory: Pointer;
  Total: Integer;
begin
  Stream := nil;
  Memory := nil;
  try
    Total := GetSize();
    GetMem(Memory, Total);
    Data := Memory;
    Total := EncodeTo(Data);
    Stream := TFileStream.Create(FileName, fmCreate);
    Stream.WriteBuffer(Memory^, Total);
    Result := True;
  except
    Result := False;
  end;
  Stream.Free();
  if Memory <> nil then
    FreeMem(Memory);
end;

procedure TMidiFile.Enum(FilterEvents: FEventFilter = nil; FilterTracks: FTrackFilter = nil);
var
  Index, Count: Integer;
  Track: TMidiTrack;
begin
  Index := 0;
  Count := Tracks.Count;
  while Index < Count do
  begin
    Track := Tracks[Index] as TMidiTrack;
    Track.OwnerMidi := Self;
    Track.OwnerIndex := Index;
    Track.Enum(FilterEvents);
    if Assigned(FilterTracks) and not FilterTracks(Track) then
    begin
      Tracks.Delete(Index);
      Dec(Count);
    end
    else
      Inc(Index);
  end;
end;

procedure TMidiFile.Fix(FixNoteOnOff: Boolean);
var
  Index: Integer;
begin
  for Index := 0 to Tracks.Count - 1 do
    (Tracks[Index] as TMidiTrack).Fix(FixNoteOnOff);
end;

function TMidiFile.CalcAbsolute(): Int64;
var
  Index: Integer;
  Value: Int64;
begin
  Result := 0;
  for Index := 0 to Tracks.Count - 1 do
  begin
    Value := (Tracks[Index] as TMidiTrack).CalcAbsolute();
    if Value > Result then
      Result := Value;
  end;
end;

// TMidiTrack

constructor TMidiTrack.Create(Owner: TMidiFile = nil; Index: Integer = -1);
begin
  Events := TCachedList.Create();
  OwnerMidi := Owner;
  OwnerIndex := Index;
end;

destructor TMidiTrack.Destroy();
begin
  Clear();
  Events.Free();
end;

procedure TMidiTrack.Clear();
begin
  Events.Clear(True);
end;

procedure TMidiTrack.Assign(From: TMidiTrack);
var
  Index: Integer;
  Event: TMidiEvent;
begin
  Clear();
  for Index := 0 to From.Events.Count - 1 do
  begin
    Event := TMidiEvent.Create(Self, Index);
    Event.Assign(From.Events[Index] as TMidiEvent);
    Events.PushRight(Event);
  end;
end;

function TMidiTrack.GetSize(): Integer;
var
  Index: Integer;
begin
  Result := 4 + 4;
  for Index := 0 to Events.Count - 1 do
    Inc(Result, (Events[Index] as TMidiEvent).GetSize());
end;

function TMidiTrack.ParseFrom(var LoadFrom: Pointer; var HaveSize, TotalSize: Integer): Boolean;
var
  Size, Index: Integer;
  Event, Previous: TMidiEvent;
begin
  Clear();
  Event := nil;
  try
    Sure(ParseMTrk(LoadFrom, Size, HaveSize, TotalSize));
    Sure(Size >= 0);
    Dec(HaveSize, Size);
    Sure(HaveSize >= 0);
    Previous := nil;
    Index := 0;
    while Size > 0 do
    begin
      Event := TMidiEvent.Create(Self, Index);
      Sure(Event.ParseFrom(Previous, LoadFrom, Size, TotalSize));
      Events.PushRight(Event);
      Inc(Index);
    end;
    Result := True;
  except
    Event.Free();
    Clear();
    Result := False;
  end;
end;

function TMidiTrack.EncodeTo(var SaveTo: Pointer): Integer;
var
  Index: Integer;
  Memory: Pointer;
  Previous: TMidiEvent;
begin
  Result := 0;
  Memory := SaveTo;
  EncodeMTrk(SaveTo, Result);
  Previous := nil;
  if (OwnerMidi <> nil) and (OwnerMidi.UseRunning) then
    for Index := 0 to Events.Count - 1 do
    begin
      Inc(Result, (Events[Index] as TMidiEvent).ConvertNoteOff(True).EncodeTo(Previous, SaveTo));
      Previous := Events[Index] as TMidiEvent;
    end
  else
    for Index := 0 to Events.Count - 1 do
      Inc(Result, (Events[Index] as TMidiEvent).ConvertNoteOff(False).EncodeTo(Previous, SaveTo));
  Inc(Result, EncodeMTrk(Memory, Result));
end;

procedure TMidiTrack.RemoveEvent(Index: Integer);
begin
  if (Index < 0) or (Index >= Events.Count) then
    Exit;
  if ((Events[Index] as TMidiEvent).DeltaTime > 0) and (Index < Events.Count - 1) then
    Inc((Events[Index + 1] as TMidiEvent).DeltaTime, (Events[Index] as TMidiEvent).DeltaTime);
  Events.Delete(Index).Free();
end;

procedure TMidiTrack.Enum(FilterEvents: FEventFilter = nil);
var
  Index, Count: Integer;
  Event: TMidiEvent;
begin
  Index := 0;
  Count := Events.Count;
  while Index < Count do
  begin
    Event := Events[Index] as TMidiEvent;
    Event.OwnerTrack := Self;
    Event.OwnerIndex := Index;
    if Assigned(FilterEvents) and not FilterEvents(Event) then
    begin
      RemoveEvent(Index);
      Dec(Count);
    end
    else
      Inc(Index);
  end;
end;

procedure TMidiTrack.Fix(FixNoteOnOff: Boolean);
var
  Index, Loop, Count: Integer;
  First, Event: TMidiEvent;
begin
  if FixNoteOnOff then
  begin
    Count := Events.Count;
    for Index := 0 to Count - 1 do
    begin
      First := Events[Index] as TMidiEvent;
      if First.IsNoteOn() then
      begin
        Loop := Index + 1;
        while Loop < Count do
        begin
          Event := Events[Loop] as TMidiEvent;
          if Event.DeltaTime = 0 then
          begin
            if Event.IsNoteOff() then
            begin
              Event.DeltaTime := First.DeltaTime;
              First.DeltaTime := 0;
              Events.Exchange(Index, Loop);
              Break;
            end;
          end
          else
            Break;
          Inc(Loop);
        end;
      end;
    end;
  end;
end;

function TMidiTrack.CalcAbsolute(): Int64;
var
  Index: Integer;
begin
  Result := 0;
  for Index := 0 to Events.Count - 1 do
  begin
    with Events[Index] as TMidiEvent do
    begin
      AbsTime := Result;
      Inc(Result, DeltaTime);
    end;
  end;
end;

// TMidiEvent

constructor TMidiEvent.Create(Owner: TMidiTrack = nil; Index: Integer = -1);
begin
  Clear();
  OwnerTrack := Owner;
  OwnerIndex := Index;
end;

destructor TMidiEvent.Destroy();
begin
  Clear();
end;

procedure TMidiEvent.Clear();
begin
  MoreData := '';
  DeltaTime := -1;
  EventType := 255;
  Param1 := 255;
  Param2 := 255;
  MetaType := 255;
  AbsTime := 0;
end;

procedure TMidiEvent.Assign(From: TMidiEvent);
begin
  DeltaTime := From.DeltaTime;
  EventType := From.EventType;
  Param1 := From.Param1;
  Param2 := From.Param2;
  MetaType := From.MetaType;
  MoreData := From.MoreData;
  AbsTime := From.AbsTime;
end;

function TMidiEvent.GetSize(): Integer;
var
  Data: Integer;
  Temp: Pointer;
begin
  Temp := @Data;
  Result := VarLenWrite(Temp, DeltaTime);
  Temp := @Data;
  if IsChannel() then
  begin
    if TwoParams() then
      Inc(Result, 3)
    else
      Inc(Result, 2);
  end
  else if IsMeta() then
    Inc(Result, 2 + Length(MoreData) + VarLenWrite(Temp, Length(MoreData)))
  else
    Inc(Result, 1 + Length(MoreData) + VarLenWrite(Temp, Length(MoreData)));
end;

function TMidiEvent.ParseFrom(var Previous: TMidiEvent; var LoadFrom: Pointer; var HaveSize, TotalSize: Integer): Boolean;
var
  Memory: Pointer;
  Count: Integer;
begin
  Clear();
  Memory := LoadFrom;
  try
    Sure(VarLenRead(LoadFrom, DeltaTime, HaveSize, TotalSize));
    Sure(ReadBytes(LoadFrom, @EventType, 1, HaveSize, TotalSize));
    if IsRunning() then
    begin
      if (OwnerTrack <> nil) and (OwnerTrack.OwnerMidi <> nil) then
        OwnerTrack.OwnerMidi.UseRunning := True;
      Sure(Previous <> nil);
      EventType := Previous.EventType and $7f;
      Inc(HaveSize);
      Dec(TotalSize);
      LoadFrom := Memory;
    end;
    if IsChannel() then
    begin
      Previous := Self;
      Sure(ReadBytes(LoadFrom, @Param1, 1, HaveSize, TotalSize));
      if TwoParams() then
        Sure(ReadBytes(LoadFrom, @Param2, 1, HaveSize, TotalSize))
    end
    else
    begin
      Previous := nil;
      if IsSystem() and not IsSysEx() then
      begin
        if IsUndef(Count) then
          Sure(Recover(LoadFrom, MoreData, HaveSize, TotalSize))
        else
        begin
          if Count > 0 then
            Sure(ReadBytes(LoadFrom, @Param1, 1, HaveSize, TotalSize));
          if Count > 1 then
            Sure(ReadBytes(LoadFrom, @Param2, 1, HaveSize, TotalSize))
        end;
      end
      else
      begin
        if IsMeta() then
          Sure(ReadBytes(LoadFrom, @MetaType, 1, HaveSize, TotalSize));
        Sure(VarLenRead(LoadFrom, Count, HaveSize, TotalSize));
        if Count > 0 then
        begin
          SetLength(MoreData, Count);
          Sure(ReadBytes(LoadFrom, PAnsiChar(MoreData), Count, HaveSize, TotalSize));
        end;
      end;
    end;
    Result := True;
  except
    Clear();
    Result := False;
  end;
end;

function TMidiEvent.EncodeTo(Previous: TMidiEvent; var SaveTo: Pointer): Integer;
begin
  Result := 0;
  Inc(Result, VarLenWrite(SaveTo, DeltaTime));
  if (Previous <> nil) and IsChannel() and ((Previous.EventType and $7f) = (EventType and $7f)) then
    EventType := EventType and $7f
  else
  begin
    EventType := EventType or $80;
    Inc(Result, WriteBytes(SaveTo, @EventType, 1));
  end;
  if IsChannel() then
  begin
    Inc(Result, WriteBytes(SaveTo, @Param1, 1));
    if TwoParams() then
      Inc(Result, WriteBytes(SaveTo, @Param2, 1));
  end
  else
  begin
    if IsMeta() then
      Inc(Result, WriteBytes(SaveTo, @MetaType, 1));
    Inc(Result, VarLenWrite(SaveTo, Length(MoreData)));
    if Length(MoreData) > 0 then
      Inc(Result, WriteBytes(SaveTo, PAnsiChar(MoreData), Length(MoreData)));
  end;
end;

function TMidiEvent.IsRunning(): Boolean;
begin
  Result := (EventType and $80) = 0;
end;

function TMidiEvent.IsSystem(): Boolean;
begin
  Result := (not IsMeta()) and (not IsChannel());
end;

function TMidiEvent.IsSysEx(): Boolean;
begin
  Result := (EventType = $f0) or (EventType = $f7);
end;

function TMidiEvent.IsSysCom(): Boolean;
begin
  Result := ((EventType and $78) = $70) and not IsSysEx();
end;

function TMidiEvent.IsSysRT(): Boolean;
begin
  Result := ((EventType and $78) = $78) and not IsMeta();
end;

function TMidiEvent.IsUndef(out Bytes: Integer): Boolean;
begin
  Result := False;
  Bytes := 0;
  case EventType and $7f of
    $74, $75, $79, $7d:
      Result := True;
    $72:
      Bytes := 2;
    $71, $73:
      Bytes := 1;
  end;
end;

function TMidiEvent.IsMeta(): Boolean;
begin
  Result := (EventType and $7f) = $7f;
end;

function TMidiEvent.IsChannel(): Boolean;
begin
  Result := (EventType and $70) <> $70;
end;

function TMidiEvent.TwoParams(): Boolean;
begin
  Result := ((EventType and $70) <> $40) and ((EventType and $70) <> $50);
end;

function TMidiEvent.IsText(): Boolean;
begin
  Result := IsMeta() and (MetaType > $00) and (MetaType <= $09);
end;

function TMidiEvent.IsNoteOff(): Boolean;
begin
  Result := IsChannel() and (((EventType and $70) = $00) or (((EventType and $70) = $10) and (Param2 = 0)));
end;

function TMidiEvent.IsNoteOn(): Boolean;
begin
  Result := IsChannel() and ((EventType and $70) = $10) and (Param2 <> 0);
end;

function TMidiEvent.IsControl(): Boolean;
begin
  Result := IsChannel() and ((EventType and $70) = $30);
end;

function TMidiEvent.IsProgram(): Boolean;
begin
  Result := IsChannel() and ((EventType and $70) = $40);
end;

function TMidiEvent.ConvertNoteOff(AsNoteOn: Boolean): TmidiEvent;
begin
  if AsNoteOn then
  begin
    if ((EventType and $70) = $00) and (Param2 = 0) then
      EventType := EventType or $10;
  end
  else if ((EventType and $70) = $10) and (Param2 = 0) then
    EventType := EventType and $ef;
  Result := Self;
end;

// EOF

end.

