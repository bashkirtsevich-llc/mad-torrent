unit Bittorrent.MerkleTree;

interface

uses
  Hash.SHA1;

type
  TMerkleHashDigest = TSHA1Digest;
  TMerkleHashCallBack = reference to procedure (const AHash: TSHA1Digest;
    ALevel: Integer);

  THashPair = packed record
    HasHash: Boolean;
    Hash: TSHA1Digest; // дайджест SHA1, так как используем алгоритм SHA1
  end;

  TMerkleHashContext = packed record
    Pairs: array of THashPair;
    CallBack: TMerkleHashCallBack;
  end;

// API
procedure MerkleHashInit  ( var   AContext  : TMerkleHashContext;
                            const ACallBack : TMerkleHashCallBack = nil);

procedure MerkleHashUpdate( var   AContext  : TMerkleHashContext;
                            const ABuffer;
                            const ADataLen  : Cardinal;
                            const AResultIdx: PInteger);

function  MerkleHashFinal ( var   AContext  : TMerkleHashContext;
                            const ALast     : Integer): TMerkleHashDigest;
// end of API

implementation

uses
  SysUtils, Classes, Math, Types;

const
  MAX_PAIRS_COUNT = 64;

procedure MerkleHashInit(var AContext: TMerkleHashContext;
  const ACallBack : TMerkleHashCallBack = nil);
begin
  AContext.CallBack := ACallBack;

  SetLength(AContext.Pairs, MAX_PAIRS_COUNT);
  FillChar(AContext.Pairs[0], SizeOf(AContext.Pairs), 0);
end;

procedure MerkleHashAdd(var AContext: TMerkleHashContext; const AHash: TSHA1Digest;
  const AResultIdx: PInteger = nil; const AIndex: Integer = 0);
var
  ctx: TSHA1Context;
  h: TSHA1Digest;
begin
  with AContext.Pairs[AIndex] do
    if HasHash then
    begin
      SHA1Init(ctx);
      SHA1Update(ctx, Hash [0], SizeOf(Hash  ));
      SHA1Update(ctx, AHash[0], SizeOf(AHash ));

      h := SHA1Final(ctx);

      if Assigned(AContext.CallBack) then
        AContext.CallBack(h, AIndex+1);

      MerkleHashAdd(AContext, h, AResultIdx, AIndex+1);

      HasHash := False;
      FillChar(Hash[0], SizeOf(Hash), 0);
    end else
    begin
      HasHash := True;
      Hash    := AHash;

      if Assigned(AResultIdx) then
        AResultIdx^ := Max(AResultIdx^, AIndex);
    end;
end;

procedure MerkleHashUpdate(var AContext: TMerkleHashContext; const ABuffer;
  const ADataLen: Cardinal; const AResultIdx: PInteger);
var
  hash: TSHA1Digest;
begin
  hash := SHA1Buf(ABuffer, ADataLen);
  if Assigned(AContext.CallBack) then
    AContext.CallBack(hash, 0);

  MerkleHashAdd(AContext, hash, AResultIdx);
end;

function MerkleHashFinal(var AContext: TMerkleHashContext;
  const ALast: Integer): TMerkleHashDigest;
var
  i: Integer;
  b: Boolean;
begin
  try
    repeat
      b := True;

      for i := 0 to ALast-1 do
        if AContext.Pairs[i].HasHash then
        begin
          MerkleHashAdd(AContext, SHA1Buf(b, 0));

          b := False;
          Break;
        end else
          b := b and not AContext.Pairs[i].HasHash;

    until b;

    for i := Length(AContext.Pairs)-1 downto 0 do
      if AContext.Pairs[i].HasHash then
      begin
        Result := AContext.Pairs[i].Hash;
        Exit;
      end;
    // результат должен быть безусловным
    FillChar(Result[0], SizeOf(TMerkleHashDigest), 0);
  finally
    AContext.CallBack := nil;
    SetLength(AContext.Pairs, 0);
  end;
end;

end.
