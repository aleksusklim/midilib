program midilib;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  UCachedList,
  UMidiLib;

var
  m: TMidiFile;

procedure my();
var
  i, j: Integer;
  track: TMidiTrack;
  event: TMidiEvent;
begin
  for i := 0 to m.Tracks.Count - 1 do
  begin
    track := m.Tracks[i] as TMidiTrack;
    for j := 0 to track.Events.Count - 1 do
    begin
      event := track.Events[j] as TMidiEvent;
      if event.DeltaTime <> 0 then
        event.DeltaTime := event.DeltaTime div 2;
    end;
  end;
end;

function fil(event: TMidiEvent): Boolean;
begin
  if event.IsSystem() or event.IsText() then
    Result := False
  else
    Result := True;
  if event.IsText() then
  begin
    Writeln(event.MoreData);
  end
  else if event.IsMeta() then
  begin
    Writeln(event.MetaType);
    if event.MetaType = 81 then
    begin
      //track.RemoveEvent(index);
    end;
  end;

end;

begin
  m := TMidiFile.Create();
  (m.Open('midi.mid'));
//  Writeln(m.CalcAbsolute());
//  my();
//  m.Tracks.Exchange(1, 2);
  (m.Enum(fil));
  (m.Enum());
  m.UseRunning := False;
  m.Save('save.mid');
  m.Fix(True);
  m.Save('fix.mid');
  m.UseRunning := True;
  m.Tracks.Exchange(0,1);
  m.Save('run.mid');
  m.Free();
end.

