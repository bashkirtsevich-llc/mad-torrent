unit Bittorrent.PiecePicker;

interface

uses
  System.SysUtils, System.Generics.Collections,
  Bittorrent, Bittorrent.Bitfield;

type
  TRarestPicker = class(TInterfacedObject, IPiecePicker)
  private
    const
      Probability = 5;
      RandomAttempts = 3;
  private
    procedure PickPiece(APeer: IPeer; AAllPeers: TList<IPeer>;
      AWant: TBitField; ACallBack: TProc<Integer>);
  end;

implementation

{ TRarestPicker }

procedure TRarestPicker.PickPiece(APeer: IPeer;
  AAllPeers: System.Generics.Collections.TList<IPeer>; AWant: TBitField;
  ACallBack: TProc<Integer>);
var
  peer: IPeer;
  b: Boolean;
  i, j, k: Integer;
  min: Byte;
  sum: TBitSum;
begin
  Assert(Assigned(ACallBack));

  { у него нет ничего интересного }
  if (APeer.Bitfield and AWant).AllFalse then
    Exit;

  sum := TBitSum.Create(AWant.Len);

  { суммируем маски }
  for peer in AAllPeers do
    sum := sum + peer.Bitfield;

  { ищем минимум в сумме и сверяем с маской нашего пира }
  min := Byte.MaxValue;
  j   := -1;
  k   := RandomAttempts;

  for i := 0 to AWant.Len - 1 do
  begin
    b := AWant[i] and (sum[i] = min) and (k > 0) and (Random(Probability) = 0);

    if AWant[i] and (sum[i] > 0) and ((sum[i] < min) or b) then
    begin
      min := sum[i];
      j   := i;

      if b then
        Dec(k);
    end;
  end;

  Assert(j > -1);

  if APeer.Bitfield[j] then
    ACallBack(j);
end;

end.
