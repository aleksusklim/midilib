program midilib;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  UCachedList,
  UMidiLib;

var
  m: TMidiFile;

begin
  m := TMidiFile.Create();
  Writeln(m.Open('midi.mid'));
  Writeln(m.GetSize());
//  m.Tracks.Exchange(1, 2);
  Writeln(m.FilterText());
  Writeln(m.Save('save.mid'));
  m.Free();
end.

