unit UCachedList;

interface

type
  TCachedListElem = class(TObject)
  private
    FNext, FPrev: TCachedListElem;
  end;

type
  TCachedList = class(TObject)
  private
    function Find(Index: Integer): TCachedListElem;
    function Init(CachedListElem: TCachedListElem): Boolean;
    procedure Reset();
    function Enum(Index: Integer): TCachedListElem;
  private
    FCount, FIndex: Integer;
    FHead, FTail, FCache: TCachedListElem;
  public
    function Delete(Index: Integer): TCachedListElem;
    procedure InsertAfter(Index: Integer; CachedListElem: TCachedListElem);
    procedure InsertBefore(Index: Integer; CachedListElem: TCachedListElem);
    procedure PushRight(CachedListElem: TCachedListElem);
    procedure PushLeft(CachedListElem: TCachedListElem);
    function PopRight(): TCachedListElem;
    function PopLeft(): TCachedListElem;
    procedure Clear(Free: Boolean);
    procedure Exchange(Index1, Index2: Integer);
  public
    property Count: Integer read FCount;
    property First: TCachedListElem read FHead;
    property Last: TCachedListElem read FTail;
    property Element[Index: Integer]: TCachedListElem read Enum; default;
  end;

implementation

function TCachedList.Find(Index: Integer): TCachedListElem;
begin
  if (FCount = 0) or (Index < 0) or (Index >= FCount) then
  begin
    Result := nil;
    Exit;
  end;
  if FCache = nil then
  begin
    if Index < FCount shr 1 then
    begin
      FCache := FHead;
      FIndex := 0;
    end
    else
    begin
      FCache := FTail;
      FIndex := FCount - 1;
    end;
  end
  else
  begin
    if Index < FIndex then
    begin
      if Index < FIndex shr 1 then
      begin
        FCache := FHead;
        FIndex := 0;
      end;
    end
    else
    begin
      if Index > (FCount + FIndex) shr 1 then
      begin
        FCache := FTail;
        FIndex := FCount - 1;
      end;
    end;
  end;
  if FIndex < Index then
    repeat
      FCache := FCache.FNext;
      Inc(FIndex);
    until FIndex = Index
  else if FIndex > Index then
    repeat
      FCache := FCache.FPrev;
      Dec(FIndex);
    until FIndex = Index;
  Result := FCache;
end;

function TCachedList.Init(CachedListElem: TCachedListElem): Boolean;
begin
  if FCount = 0 then
  begin
    FHead := CachedListElem;
    FTail := CachedListElem;
    FCache := FHead;
    FIndex := 0;
    FCount := 1;
    Result := True;
  end
  else
    Result := False;
end;

procedure TCachedList.Reset();
begin
  FCount := 0;
  FIndex := 0;
  FCache := nil;
  FHead := nil;
  FTail := nil;
end;

function TCachedList.Delete(Index: Integer): TCachedListElem;
begin
  if Index = 0 then
  begin
    Result := PopLeft();
    Exit;
  end
  else if Index = FCount - 1 then
  begin
    Result := PopRight();
    Exit;
  end;
  if Find(Index) = nil then
  begin
    Result := nil;
    Exit;
  end;
  Result := FCache;
  Dec(FCount);
  FCache.FNext.FPrev := FCache.FPrev;
  FCache.FPrev.FNext := FCache.FNext;
  FCache := FCache.FNext;
  Result.FNext := nil;
  Result.FPrev := nil;
end;

procedure TCachedList.InsertAfter(Index: Integer; CachedListElem: TCachedListElem);
begin
  if (CachedListElem = nil) or Init(CachedListElem) then
    Exit;
  if Index = FCount - 1 then
  begin
    PushRight(CachedListElem);
    Exit;
  end;
  Find(Index);
  Inc(FCount);
  FCache.FNext.FPrev := CachedListElem;
  CachedListElem.FNext := FCache.FNext;
  FCache.FNext := CachedListElem;
  CachedListElem.FPrev := FCache;
end;

procedure TCachedList.InsertBefore(Index: Integer; CachedListElem: TCachedListElem);
begin
  if (CachedListElem = nil) or Init(CachedListElem) then
    Exit;
  if Index = 0 then
  begin
    PushLeft(CachedListElem);
    Exit;
  end;
  Find(Index);
  Inc(FCount);
  FCache.FPrev.FNext := CachedListElem;
  CachedListElem.FPrev := FCache.FPrev;
  FCache.FPrev := CachedListElem;
  CachedListElem.FNext := FCache;
  Inc(FIndex);
end;

procedure TCachedList.PushRight(CachedListElem: TCachedListElem);
begin
  if (CachedListElem = nil) or Init(CachedListElem) then
    Exit;
  Inc(FCount);
  FTail.FNext := CachedListElem;
  CachedListElem.FPrev := FTail;
  CachedListElem.FNext := nil;
  FTail := CachedListElem;
end;

procedure TCachedList.PushLeft(CachedListElem: TCachedListElem);
begin
  if (CachedListElem = nil) or Init(CachedListElem) then
    Exit;
  Inc(FCount);
  FHead.FPrev := CachedListElem;
  CachedListElem.FNext := FHead;
  CachedListElem.FPrev := nil;
  FHead := CachedListElem;
  Inc(FIndex);
end;

function TCachedList.PopRight(): TCachedListElem;
begin
  Result := FTail;
  if FHead = FTail then
  begin
    Reset();
    Exit;
  end;
  FTail := Result.FPrev;
  FTail.FNext := nil;
  Result.FPrev := nil;
  Dec(FCount);
  if FCache = Result then
  begin
    FCache := FTail;
    Dec(FIndex);
  end;
end;

function TCachedList.PopLeft(): TCachedListElem;
begin
  Result := FHead;
  if FHead = FTail then
  begin
    Reset();
    Exit;
  end;
  FHead := Result.FNext;
  FHead.FPrev := nil;
  Result.FNext := nil;
  Dec(FCount);
  Dec(FIndex);
end;

procedure TCachedList.Clear(Free: Boolean);
begin
  if Free then
    while FHead <> nil do
    begin
      FCache := FHead.FNext;
      FHead.Free();
      FHead := FCache;
    end;
  Reset();
end;

function TCachedList.Enum(Index: Integer): TCachedListElem;
begin
  if Index = 0 then
    Result := FHead
  else if Index = FCount - 1 then
    Result := FTail
  else
  begin
    if FCache <> nil then
    begin
      if Index = FIndex then
        Result := FCache
      else if Index = FIndex + 1 then
      begin
        FCache := FCache.FNext;
        Result := FCache;
        Inc(FIndex);
      end
      else if Index = FIndex - 1 then
      begin
        FCache := FCache.FPrev;
        Result := FCache;
        Dec(FIndex);
      end
      else
        Result := Find(Index);
    end
    else
      Result := Find(Index);
  end;
end;

procedure TCachedList.Exchange(Index1, Index2: Integer);
var
  Next, Prev, Other: TCachedListElem;
begin
  Other := Find(Index1);
  if (Other = nil) or (Find(Index2) = nil) then
    Exit;
  if Other.FNext = FCache then
  begin
    Other.FNext := FCache.FNext;
    FCache.FPrev := Other.FPrev;
    Other.FPrev := FCache;
    FCache.FNext := Other;
  end
  else if FCache.FNext = Other then
  begin
    Other.FPrev := FCache.FPrev;
    FCache.FNext := Other.FNext;
    Other.FNext := FCache;
    FCache.FPrev := Other;
  end
  else
  begin
    Next := FCache.FNext;
    Prev := FCache.FPrev;
    FCache.FNext := Other.FNext;
    FCache.FPrev := Other.FPrev;
    Other.FNext := Next;
    Other.FPrev := Prev;
  end;
  if FCache.FNext <> nil then
    FCache.FNext.FPrev := FCache;
  if FCache.FPrev <> nil then
    FCache.FPrev.FNext := FCache;
  if Other.FNext <> nil then
    Other.FNext.FPrev := Other;
  if Other.FPrev <> nil then
    Other.FPrev.FNext := Other;
  if FHead = Other then
    FHead := FCache
  else if FHead = FCache then
    FHead := Other;
  if FTail = Other then
    FTail := FCache
  else if FTail = FCache then
    FTail := Other;
  FCache := nil;
end;

end.

