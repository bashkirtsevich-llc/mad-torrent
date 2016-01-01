unit Shareman.Bittorrent;

interface

uses
  System.Generics.Collections, System.Generics.Defaults,
  Basic.UniString,
  Shareman, Shareman.Bitfield,
  IdGlobal;

type
  {$REGION 'BTMessages'}
  IBTMessage = interface(IMessage)
  ['{229FBB39-1778-4B78-B810-8FBCC8B210A2}']
  end;

  TBTMessageID = (
    idChoke         = 0,
    idUnchoke       = 1,
    idInterested    = 2,
    idNotInterested = 3,
    idHave          = 4,
    idBitfield      = 5,
    idRequest       = 6,
    idPiece         = 7,
    idCancel        = 8,
    idPort          = 9,
    idExtended      = 20
  );

  IBTFixedMessage = interface(IBTMessage)
  ['{F120467F-3088-4E50-815A-717798367D03}']
    function GetMessageID: TBTMessageID;

    property MessageID: TBTMessageID read GetMessageID;
  end;

  { пустое сообщение, или сообщение, которое не удалось идентифицировать }
  IBTKeepAliveMessage = interface(IBTMessage)
  ['{E672DBB7-31E8-4B97-B6CF-A37B611EC447}']
    function GetDummy: TUniString;

    property Dummy: TUniString read GetDummy; { мусор }
  end;

  IBTChokeMessage = interface(IBTFixedMessage)
  ['{90A75323-8002-4E75-96B3-B0AD86107755}']
  end;

  IBTUnchokeMessage = interface(IBTFixedMessage)
  ['{E80C43DD-C663-4044-A883-455C8DC988A1}']
  end;

  IBTInterestedMessage = interface(IBTFixedMessage)
  ['{0A380AF8-7986-4EB3-AA55-CA77C2657F00}']
  end;

  IBTNotInterestedMessage = interface(IBTFixedMessage)
  ['{620365DA-DE5A-4C6C-AEA4-131521CAAD9C}']
  end;

  IBTHaveMessage = interface(IBTFixedMessage)
  ['{D5FBDAB6-BABF-4D12-A2AF-A341D2F48DB7}']
    function GetPieceIndex: Integer;

    property PieceIndex: Integer read GetPieceIndex;
  end;

  IBTBitfieldMessage = interface(IBTFixedMessage)
  ['{4BD183FB-7A32-4688-A403-03482EF221A3}']
    function GetBitField: TBitField;

    property BitField: TBitField read GetBitField;
  end;

  IBTRequestMessage = interface(IBTFixedMessage)
  ['{37267B1A-0DF8-425A-9B1C-2E3DABA18B38}']
    function GetPieceIndex: Integer;
    function GetOffset: Integer;
    function GetSize: Integer;

    property PieceIndex: Integer read GetPieceIndex;
    property Offset: Integer read GetOffset;
    property Size: Integer read GetSize;
  end;

  IBTPieceMessage = interface(IBTFixedMessage)
  ['{9ED990F7-A704-46ED-9492-43E16566AC99}']
    function GetPieceIndex: Integer;
    function GetOffset: Integer;
    function GetBlock: TUniString;

    property PieceIndex: Integer read GetPieceIndex;
    property Offset: Integer read GetOffset;
    property Block: TUniString read GetBlock;
  end;

  IBTCancelMessage = interface(IBTFixedMessage)
  ['{EA4C56F8-0617-4FB8-A795-10A19981A86F}']
    function GetPieceIndex: Integer;
    function GetOffset: Integer;
    function GetSize: Integer;

    property PieceIndex: Integer read GetPieceIndex;
    property Offset: Integer read GetOffset;
    property Size: Integer read GetSize;
  end;

  IBTPortMessage = interface(IBTFixedMessage)
  ['{C71C7DC2-CA7A-4D24-B71A-68C477746563}']
    function GetPort: TIdPort;

    property Port: TIdPort read GetPort;
  end;

  IBTHandshakeMessage = interface(IBTMessage)
  ['{3F782B6B-8C70-48F6-ADB0-0DBBD2014416}']
    function GetInfoHash: TUniString;
    function GetPeerID: TUniString;
    function GetFlags: TUniString;
    function GetSupportsDHT: Boolean;
    function GetSupportsExtendedMessaging: Boolean;
    function GetSupportsFastPeer: Boolean;

    property InfoHash: TUniString read GetInfoHash;
    property PeerID: TUniString read GetPeerID;
    property Flags: TUniString read GetFlags;
    property SupportsDHT: Boolean read GetSupportsDHT;
    property SupportsExtendedMessaging: Boolean read GetSupportsExtendedMessaging;
    property SupportsFastPeer: Boolean read GetSupportsFastPeer;
  end;

  IBTExtension = interface
  ['{28B28D8A-C375-490B-9AF2-183682E3916A}']
    function GetData: TUniString;
    function GetSize: Integer;
    function GetSupportName: string;

    property Data: TUniString read GetData;
    property Size: Integer read GetSize;
    property SupportName: string read GetSupportName;
  end;

  IBTExtensionHandshake = interface(IBTExtension)
  ['{B8188CDB-CFDB-43EB-B8B5-04B245978EBE}']
    function GetClientVersion: string;
    function GetPort: TIdPort;
    function GetMetadataSize: Integer;
    function GetSupports: TDictionary<string, Byte>;

    property ClientVersion: string read GetClientVersion;
    property Port: TIdPort read GetPort;
    property MetadataSize: Integer read GetMetadataSize;
    property Supports: TDictionary<string, Byte> read GetSupports;
  end;

  TBTMetadataMessageType = (mmtRequest = 0, mmtData = 1, mmtReject = 2);

  IBTExtensionMetadata = interface(IBTExtension)
  ['{B9DBBB68-96CC-4D1A-AA1F-3B8E056278D8}']
    function GetMessageType: TBTMetadataMessageType;
    function GetPiece: Integer;
    function GetMetadata: TUniString;

    property MessageType: TBTMetadataMessageType read GetMessageType;
    property Piece: Integer read GetPiece;
    property Metadata: TUniString read GetMetadata;
  end;

  IBTExtensionMessage = interface(IBTMessage)
  ['{AA21A80E-6D53-411D-BB0D-B7E41DB2238C}']
    function GetExtension: IBTExtension;
    function GetMessageID: Byte;

    property MessageID: Byte read GetMessageID;
    property Extension: IBTExtension read GetExtension;
  end;
  {$ENDREGION}

  EBittorrentException = class(ESharemanException);
  ETrackerFailure = class(EBittorrentException);

implementation

end.
