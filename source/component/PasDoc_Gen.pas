{$B-}
{ @abstract(basic doc generator object)
  @author(Johannes Berg <johannes@sipsolutions.de>)
  @author(Ralf Junker (delphi@zeitungsjunge.de))
  @author(Ivan Montes Velencoso (senbei@teleline.es))
  @author(Marco Schmidt (marcoschmidt@geocities.com))
  @author(Philippe Jean Dit Bailleul (jdb@abacom.com))
  @author(Rodrigo Urubatan Ferreira Jardim (rodrigo@netscape.net))
  @author(Grzegorz Skoczylas <gskoczylas@program.z.pl>)
  @author(Pierre Woestyn <pwoestyn@users.sourceforge.net>)
  @created(30 Aug 1998)
  @cvs($Date$)

  GenDoc contains the basic documentation generator object @link(TDocGenerator).
  It is not sufficient by itself but the basis for all generators that produce
  documentation in a specific format like HTML or LaTex.
  They override @link(TDocGenerator)'s virtual methods. }

unit PasDoc_Gen;

interface

uses
  PasDoc_Items,
  PasDoc_Languages,
  StringVector,
  ObjectVector,
  PasDoc_HierarchyTree,
  PasDoc_Types,
  PasDoc_RunHelp,
  Classes,
  PasDoc_TagManager;

const
  { set of characters, including all letters and the underscore }
  IdentifierStart = ['A'..'Z', 'a'..'z', '_'];

  { set of characters, including all characters from @link(IdentifierStart)
    plus the ten decimal digits }
  IdentifierOther = ['A'..'Z', 'a'..'z', '_', '0'..'9', '.'];

  { number of overview files that pasdoc generates for
    multiple-document-formats like HTML (see @link(THTMLDocGenerator)) }
  NUM_OVERVIEW_FILES = 10;
  NUM_OVERVIEW_FILES_USED = 8;

  { names of all overview files, extensions not included }
  OverviewFilenames: array[0..NUM_OVERVIEW_FILES - 1] of shortstring =
  ( 'AllUnits',
    'ClassHierarchy',
    'AllClasses',
    'AllTypes',
    'AllVariables',
    'AllConstants',
    'AllFunctions',
    'AllIdentifiers',
    'GVUses',
    'GVClasses');

type
  TCodeType = (ctWhiteSpace, ctString, ctCode, ctEndString, ctChar,
    ctParenComment, ctBracketComment, ctSlashComment, ctCompilerComment,
    ctEndComment);

  { @abstract(class for spell-checking) }
  TSpellingError = class
  public
    { the mis-spelled word }
    Word: string;
    { offset inside the checked string }
    Offset: Integer;
    { comma-separated list of suggestions }
    Suggestions: string;
  end;

  { Result for @link(TDocGenerator.CreateStream) }
  TCreateStreamResult = (
    { normal result }
    csCreated,
    { if file exists this will be returned, unless overwrite is true }
    csExisted,
    { returned on error }
    csError
  );

  { This is a temporary thing, needed to implement WriteCodeWithLinksCommon,
    that replaces previous THTMLDocGenerator.WriteCodeWithLinks
    and TTexGenerator.WriteCodeWithLinks that previously shared some
    copy&pasted code.
    
    This will be replaced with a protected virtual method of TDocGenerator 
    later, and with a different parameter list (for now, noone knows
    what href and localcss params should do in latex output (actually
    they are ignored in latex output),  but I'll try to not fix everything 
    at once, to not break some things). }
  TWriteLinkProc = procedure (const href, caption, localcss: string) of object;
  
  TLinkLook = (llDefault, llFull, llStripped);

  { @abstract(basic documentation generator object)
    @author(Marco Schmidt (marcoschmidt@geocities.com))
    This abstract object will do the complete process of writing
    documentation files.
    It will be given the collection of units that was the result of the
    parsing process and a configuration object that was created from default
    values and program parameters.
    Depending on the output format, one or more files may be created (HTML
    will create several, Tex only one). }
  TDocGenerator = class(TComponent)
  private
    FCheckSpelling,
    FSpellCheckStarted: boolean;
    FAspellLanguage: string;
    FAspellPipe: TRunRecord;
    FIgnoreWordsFile,
    FAspellMode: string;
    FLinkGraphVizUses: string;
    FLinkGraphVizClasses: string;
    FCurrentItem: TPasItem;
    FAutoAbstract: boolean;
    FLinkLook: TLinkLook;

    { This just calls OnMessage (if assigned), but it appends
      to AMessage FCurrentItem.QualifiedName. }
    procedure DoMessageFromExpandDescription(
      const MessageType: TMessageType; const AMessage: string; 
      const AVerbosity: Cardinal);

    procedure HandleLinkTag(TagManager: TTagManager;
      const TagName, TagDesc: string; var ReplaceStr: string);

    (* Called when an @longcode tag is encountered. This tag is used to format
      the enclosed text in the same way it would be in Delphi (using the
      default settings in Delphi).

    Because any character including the ')' character might be in your code,
    there needs to be a special way to mark the end of the @longCode tag.
    To do this include a special character such as "#' just after the opening
    '(' of the @longcode tag.  Include that same character again just before
    the closing ')' of the @longcode tag.

      Here is an example of the @@longcode tag in use. Check the source code
      to see how it was done.

      @longCode(#
procedure TForm1.FormCreate(Sender: TObject);
var
  i: integer;
begin
  // Note that your comments are formatted.
  {$H+} // You can even include compiler directives.
  // reserved words are formatted in bold.
  for i := 1 to 10 do
  begin
    It is OK to include pseudo-code like this line.
    // It will be formatted as if it were meaningful pascal code.
  end;
end;
      #)
      *)

    procedure HandleLongCodeTag(TagManager: TTagManager;
      const TagName, TagDesc: string; var ReplaceStr: string);
    procedure HandleClassnameTag(TagManager: TTagManager;
      const TagName, TagDesc: string; var ReplaceStr: string);
    procedure HandleHtmlTag(TagManager: TTagManager;
      const TagName, TagDesc: string; var ReplaceStr: string);
    procedure HandleLatexTag(TagManager: TTagManager;
      const TagName, TagDesc: string; var ReplaceStr: string);
    procedure HandleInheritedTag(TagManager: TTagManager;
      const TagName, TagDesc: string; var ReplaceStr: string);
    procedure HandleNameTag(TagManager: TTagManager;
      const TagName, TagDesc: string; var ReplaceStr: string);
    procedure HandleCodeTag(TagManager: TTagManager;
      const TagName, TagDesc: string; var ReplaceStr: string);
    procedure HandleLiteralTag(TagManager: TTagManager;
      const TagName, TagDesc: string; var ReplaceStr: string);
    procedure HandleBrTag(TagManager: TTagManager;
      const TagName, TagDesc: string; var ReplaceStr: string);

  protected
    FAbbreviations: TStringList;
    FGraphVizClasses: boolean;
    FGraphVizUses: boolean;
    { the (human) output language of the documentation file(s) }
    FLanguage: TPasDocLanguages;
    { Name of the project to create. }
    FProjectName: string;
    { if true, no link to pasdoc homepage will be included at the bottom of
      HTML files;
      default is false }
    FNoGeneratorInfo: Boolean;
    { the output stream that is currently written to; depending on the
      output format, more than one output stream will be necessary to
      store all documentation }
    FCurrentStream: TStream;
    { Title of documentation. }
    FTitle: string;
    { destination directory for documentation; must include terminating
      forward slash or backslash so that valid file names can be created
      by concatenating DestinationDirectory and a pathless file name }
    FDestDir: string;

    FOnMessage: TPasDocMessageEvent;

    FClassHierarchy: TStringCardinalTree;

    procedure SetAbbreviations(const Value: TStringList);
    function GetLanguage: TLanguageID;
    procedure SetLanguage(const Value: TLanguageID);
    procedure SetDestDir(const Value: string);

    procedure DoError(const AMessage: string; const AArguments: array of const;
      const AExitCode: Word);
    procedure DoMessage(const AVerbosity: Cardinal;
      const MessageType: TMessageType; const AMessage: string;
      const AArguments: array of const);

    property CurrentStream: TStream read FCurrentStream;

    procedure CreateClassHierarchy;

    { This is used in descendants in their WriteCodeWithLinks routines.
      Sorry, no better docs for it yet, because this is a work-in-progress
      on merging code that was previously copy&pasted between html and latex
      generator. See also comments at @link(TWriteLinkProc) }
    procedure WriteCodeWithLinksCommon(const p: TPasItem;
      const Code: string; const ItemLink: string;
      const NameLinkBegin, NameLinkEnd: string;
      WriteLink: TWriteLinkProc);
  protected
    { list of all units that were successfully parsed }
    FUnits: TPasUnits;

    { If field @link(CurrentStream) is assigned, it is disposed and set to nil. }
    procedure CloseStream;

    { Makes a String look like a coded String, i.e. <CODE>TheString</CODE>
      in Html.
      @param(s is the string to format)
      @returns(the formatted string) 
    }
    function CodeString(const s: string): string; virtual; abstract;

    { Mark the string as a parameter, e.g. <b>TheString</b> }
    function ParameterString(const ParamType, Param: string): string; virtual;

    { Converts for each character in S, thus assembling a
      String that is returned and can be written to the documentation file.

      The @@ character should not be converted, this will be done later on.
    }
    function ConvertString(const s: string): string; virtual; abstract;
    { Converts a character to its converted form. This method
      should always be called to add characters to a string.

      @@ should also be converted by this routine.
    }
    function ConvertChar(c: char): string; virtual; abstract;

    { This function is supposed to return a reference to an item, that is the
      name combined with some linking information like a hyperlink element in
      HTML or a page number in Tex. }
    function CreateLink(const Item: TPasItem): string; virtual;

    { If @link(CurrentStream) still exists (<> nil), it is closed.
      Then, a new output stream in the destination directory with given
      name and file extension typical for this document format is created and
      assigned to @link(CurrentStream).
      No path or extension should therefore be in Name.
      Typical values for Name would be 'Objects' or 'AllUnits'.
      Returns true if creation was successful, false otherwise. }
    function CreateStream(const AName: string; const AOverwrite: boolean): 
      TCreateStreamResult;

    { Must be overwritten.
      From an item name and its link, this creates a language-specific
      reference to that item. }
    function CreateReferencedLink(ItemName, Link: string): string; virtual; abstract;

    (*Takes description D of the Item, expands links (using Item),
      converts output-specific characters.
      
      Note that you can't process with this function more than once
      the same Description (i.e. like
      @longcode(#
        { BAD EXAMPLE }
        Description := ExpandDescription(Item, Description);
        Description := ExpandDescription(Item, Description);
      #)) because output of this function is already something
      ready to be included in final doc output, it shouldn't be
      processed once more, moreover this function initializes
      some properties of Item to make them also in the 
      "already-processed" form (ready to be included in final docs).
      
      Note that you can call it only when not Item.WasDeserialized.
      That's because the current approach to cache stores in the cache
      items in the state already processed by this function,
      i.e. after all ExpandDescription calls were made. 
      
      Meaning of WantFirstSentenceEnd and FirstSentenceEnd:
      see @link(TTagManager.Execute). *)
    function ExpandDescription(Item: TPasItem; 
      const Description: string;
      WantFirstSentenceEnd: boolean;
      var FirstSentenceEnd: Integer): string; overload; 

    { Same thing as ExpandDescription(Item, Description, false, Dummy) }
    function ExpandDescription(Item: TPasItem; 
      const Description: string): string; overload;

    { Searches for an email address in String S. Searches for first appearance
      of the @@ character}
    function ExtractEmailAddress(s: string; var S1, S2, EmailAddress: string): Boolean;

    { Searches all items in all units (given by field @link(Units)) for item
      S1.S2.S3 (first N  strings not empty).
      Returns a pointer to the item on success, nil otherwise. }
    function FindGlobal(const S1, S2, S3: string; const n: Integer): TPasItem;

    function GetCIOTypeName(MyType: TCIOType): string;

    { Abstract function that provides file extension for documentation format.
      Must be overwritten by descendants. }
    function GetFileExtension: string; virtual; abstract;

    { Loads descriptions from file N and replaces or fills the corresponding
      comment sections of items. }
    procedure LoadDescriptionFile(n: string);

    function SearchItem(s: string; const Item: TPasItem): TPasItem;

    { Searches for an item of name S which was linked in the description
      of Item. Starts search within item, then does a search on all items in all
      units using @link(FindGlobal).
      Returns a link as String on success or an empty String on failure. 
      
      How exactly link does look like is controlled by @link(LinkLook) property. 
      
      LinkDisplay, if not '', specifies explicite the display text for link. }
    function SearchLink(s: string; const Item: TPasItem;
      const LinkDisplay: string): string;

    { This calls SearchLink(Identifier, Item).
      If SearchLink succeeds (returns something <> ''), it simply returns
      what SearchLink returned.

      But if SearchLink fails, it
      - gives a warning to a user
        Format(WarningFormat, [Identifier, Item.QualifiedName]
      - returns CodeString(ConvertString(Identifier)) }
    function SearchLinkOrWarning(const Identifier: string; 
      Item: TPasItem; const LinkDisplay: string;
      const WarningFormat: string): string;

    { A link provided in a tag can be made up of up to three parts,
      separated by dots.
      If this link is not a valid identifier or if it has more than
      three parts, false is returned, true otherwise.
      The parts are returned in S1, S2 and S3, with the number of
      parts minus one being returned in N. }
    function SplitLink(s: string; var S1, S2, S3: string; var n: Integer): Boolean;

    procedure StoreDescription(ItemName: string; var t: string);

    { Writes all information on a class, object or interface (CIO) to output,
      at heading level HL. }
    procedure WriteCIO(HL: integer; const CIO: TPasCio); virtual; abstract;

    { Writes all classes, interfaces and objects in C to output, calling
      @link(WriteCIO) with each, at heading level HL. }
    procedure WriteCIOs(HL: integer; c: TPasItems); virtual;

    { Abstract procedure, must be overwritten by descendants.
      Writes a list of all classes, interfaces and objects in C at heading
      level HL to output. }
    procedure WriteCIOSummary(HL: integer; c: TPasItems); virtual;

    { Writes collection T, which is supposed to contain constant items only
      to output at heading level HL with heading FLanguage.Translation[trTYPES) calling
      @link(WriteItems).
      Can be overwritten by descendants. }
    procedure WriteConstants(HL: integer; c: TPasItems); virtual;

    { If they are assigned, the date values for creation time and time of last
      modification are written to output at heading level HL. }
    procedure WriteDates(const HL: integer; const Created, LastMod: string);
      virtual; abstract;

    { Writes an already-converted description T to output.
      Takes @link(TPasItem.DetailedDescription) if available,
      @link(TPasItem.AbstractDescription) otherwise.
      If none of them is assigned, nothing is written. }
    procedure WriteDescription(HL: integer; const Heading: string; const Item:
      TPasItem);

    { Writes a list of functions / procedure or constructors / destructors /
      methods I to output.
      Heading level HL is used.
      If Methods is true, the 'Methods' heading is used, 'Functions and
      procedures' otherwise.
      Usually, a list of all items is written first, followed by detailed
      descriptions of each item.
      However, this is dependent on the output format. }
    procedure WriteFuncsProcs(const HL: integer; const Methods: Boolean; const
      FuncsProcs: TPasMethods); virtual; abstract;

    { Abstract procedure that must be overwritten by descendants.
      Writes a heading S at level HL to output.
      In HTML, heading levels are regarded by choosing the appropriate
      element from H1 to H6.
      The minimum heading level is 1, the maximum level depends on the
      output format.
      However, it is no good idea to choose a heading level larger than
      five or six.
      Anyway, a descendant should be able to deal with to large HL values,
      e.g. by assigning subsubsection to all Tex headings >= 4. }
    procedure WriteHeading(HL: integer; const s: string); virtual; abstract;

    { Writes items in I to output, including a heading of level HL and text
      Heading.
      Each item in I should be written with its short description and a
      reference.
      In HTML, this results in a table with two columns. }
    procedure WriteItems(HL: integer; Heading: string; const Anchor: string;
      const i: TPasItems); virtual; abstract;

    { Abstract method, must be overwritten by descendants to implement
      functionality.
      Writes a list of properties P to output.
      Heading level HL is used for the heading FLanguage.Translation[trPROPERTIES). }
    procedure WriteProperties(HL: integer; const p: TPasProperties); virtual;
      abstract;

    { Writes String S to output, converting each character using
      @link(ConvertString). }
    procedure WriteConverted(const s: string; Newline: boolean); overload; virtual;

    procedure WriteConverted(const s: string); overload; virtual;

    { Simply copies characters in text T to output. }
    procedure WriteDirect(const t: string; Newline: boolean); overload; virtual;

    procedure WriteDirect(const t: string); overload; virtual; 
    
    { Writes collection T, which is supposed to contain type items (TPasItem) to
      output at heading level HL with heading FLanguage.Translation[trTYPES) calling
      @link(WriteItems).
      Can be overwritten in descendants. }
    procedure WriteTypes(const HL: integer; const t: TPasItems); virtual;

    { Abstract method that writes all documentation for a single unit U to
      output, starting at heading level HL.
      Implementation must be provided by descendant objects and is dependent
      on output format.
      Will call some of the WriteXXX methods like @link(WriteHeading),
      @link(WriteCIOs) or @link(WriteUnitDescription). }
    procedure WriteUnit(const HL: integer; const U: TPasUnit); virtual;
      abstract;

    { Abstract method to be implemented by descendant objects.
      Writes the (detailed, if available) description T of a unit to output,
      including a FLanguage.Translation[trDESCRIPTION) headline at heading level HL. }
    procedure WriteUnitDescription(HL: integer; U: TPasUnit); virtual; abstract;

    { Writes documentation for all units, calling @link(WriteUnit) for each
      unit. }
    procedure WriteUnits(const HL: integer);
    
    { Writes collection V, which is supposed to contain variable items (TPasItem)
      to output at heading level HL with heading FLanguage.Translation[trTYPES) calling
      @link(WriteItems).
      Can be overwritten in descendants. }
    procedure WriteVariables(const HL: integer; const V: TPasItems); virtual;

    procedure WriteStartOfCode; virtual;

    procedure WriteEndOfCode; virtual;

    { output graphviz uses tree }
    procedure WriteGVUses;
    { output graphviz class tree }
    procedure WriteGVClasses;

    { starts the spell checker - currently linux only }
    procedure StartSpellChecking(const AMode: string);

    { checks a word and returns suggestions.
      Will create an entry in AWords for each wrong word,
      and the object (if not nil meaning no suggestions) will contain
      another string list with suggestions. The value will be the
      offset from the start of AString.
      Example:
        check the string "the quieck brown fox"
        result is:
        AErrors contains a single item:
          quieck=5 with object a stringlist containing something like the words
          quick, quiesce, ... }
    procedure CheckString(const AString: string; const AErrors: TObjectVector);

    { closes the spellchecker }
    procedure EndSpellChecking;
    { FormatPascalCode will cause Line to be formatted in
      the way that Pascal code is formatted in Delphi.
      Note that given Line is taken directly from what user put
      inside @longcode(), it is not even processed by ConvertString.
      You should process it with ConvertString if you want. }
    function FormatPascalCode(const Line: string): string; virtual;
    // FormatCode will cause AString to be formatted in the
    // way that Pascal statements are in Delphi.
    function FormatCode(AString: string): string; virtual;
    // FormatComment will cause AString to be formatted in
    // the way that comments other than compiler directives are
    // formatted in Delphi.  See: @link(FormatCompilerComment).
    function FormatComment(AString: string): string; virtual;
    // FormatKeyWord will cause AString to be formatted in
    // the way that strings are formatted in Delphi.
    function FormatString(AString: string): string; virtual;
    // FormatKeyWord will cause AString to be formatted in
    // the way that reserved words are formatted in Delphi.
    function FormatKeyWord(AString: string): string; virtual;
    // FormatCompilerComment will cause AString to be formatted in
    // the way that compiler directives are formatted in Delphi.
    function FormatCompilerComment(AString: string): string; virtual;
    
    { This is paragraph marker in output documentation.
    
      Default implementation in this class simply returns ' ' 
      (one space). }
    function Paragraph: string; virtual;
    
    { S is guaranteed (guaranteed by the user) to be correct html content,
      this is taken directly from parameters of @html tag.
      Override this function to decide what to put in output on such thing.

      Note that S is not processed in any way, even with ConvertString.
      So you're able to copy user's input inside @@html() 
      verbatim to the output.

      The default implementation is this class simply discards it,
      i.e. returns always ''. Generators that know what to do with
      HTML can override this with simple "Result := S". }
    function HtmlString(const S: string): string; virtual;
    
    { This is equivalent of @link(HtmlString) for @@latex tag.
      
      The default implementation is this class simply discards it,
      i.e. returns always ''. Generators that know what to do with raw
      LaTeX markup can override this with simple "Result := S". }
    function LatexString(const S: string): string; virtual;
    
    { This returns markup that forces line break in given output
      format (e.g. '<br>' in html or '\\' in LaTeX).
      It is used on @br tag (but may also be used on other 
      occasions in the future).
      
      In this class it returns '', because it's valid for
      an output generator to simply ignore @br tags if linebreaks
      can't be expressed in given output format. }
    function LineBreak: string; virtual;
    
    { This should return markup upon finding URL in description.
      E.g. HTML generator will want to wrap this in 
      <a href="...">...</a>.
      
      Note that passed here URL is *not* processed by @link(ConvertString)
      (because sometimes it could be undesirable).
      If you want you can process URL with ConvertString when
      overriding this method.
      
      Default implementation in this class simply returns ConvertString(URL).
      This is good if your documentation format does not support
      anything like URL links. }
    function URLLink(const URL: string): string; virtual;
  public

    { Creates anchors and links for all items in all units. }
    procedure BuildLinks; virtual;
    
    { Calls @link(ExpandDescription) for each item in each unit of
      @link(Units). }
    procedure ExpandDescriptions;

    { Assumes C contains file names as PString variables.
      Calls @link(LoadDescriptionFile) with each file name. }
    procedure LoadDescriptionFiles(const c: TStringVector);

    { Must be overwritten, writes all documentation.
      Will create either a single file or one file for each unit and each
      class, interface or object, depending on output format. }
    procedure WriteDocumentation; virtual;

    property Units: TPasUnits read FUnits write FUnits;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ParseAbbreviationsFile(const AFileName: string);

  published
    { the (human) output language of the documentation file(s) }
    property Language: TLanguageID read GetLanguage write SetLanguage
      default DEFAULT_LANGUAGE;
    { Name of the project to create. }
    property ProjectName: string read FProjectName write FProjectName;
    
    { "generator info" are 
      things that can change with each invocation of pasdoc,
      with different pasdoc binary etc.
      
      This includes
      - time of generating docs
      - compiler name and version used to compile pasdoc, 
        time of compilation and such
      - pasdoc's version
      Default value is false (i.e. show them), 
      as this information is generally considered useful.
      
      Setting this to true is useful for automatically comparing two
      versions of pasdoc's output (e.g. when trying to automate pasdoc's 
      tests). }
    property NoGeneratorInfo: Boolean 
      read FNoGeneratorInfo write FNoGeneratorInfo default False;
    
    { the output stream that is currently written to; depending on the
      output format, more than one output stream will be necessary to
      store all documentation }
    property Title: string read FTitle write FTitle;

    { destination directory for documentation; must include terminating
      forward slash or backslash so that valid file names can be created
      by concatenating DestinationDirectory and a pathless file name }
    property DestinationDirectory: string read FDestDir write SetDestDir;

    property OnMessage: TPasDocMessageEvent read FOnMessage write FOnMessage;

    { generate a GraphViz diagram for the units dependencies }
    property OutputGraphVizUses: boolean read FGraphVizUses write FGraphVizUses
      default false;
    { generate a GraphViz diagram for the Class hierarchy }
    property OutputGraphVizClassHierarchy: boolean 
      read FGraphVizClasses write FGraphVizClasses default false;
    { link the GraphViz uses diagram }
    property LinkGraphVizUses: string read FLinkGraphVizUses write FLinkGraphVizUses;
    { link the GraphViz classes diagram }
    property LinkGraphVizClasses: string read FLinkGraphVizClasses write FLinkGraphVizClasses;

    property Abbreviations: TStringList read FAbbreviations write SetAbbreviations;

    property CheckSpelling: boolean read FCheckSpelling write FCheckSpelling
      default false;
    property AspellLanguage: string read FAspellLanguage write FAspellLanguage;
    property IgnoreWordsFile: string read FIgnoreWordsFile write FIgnoreWordsFile;

    { The meaning of this is just like --auto-abstract command-line option.
      It is used in @link(ExpandDescriptions). }
    property AutoAbstract: boolean read FAutoAbstract write FAutoAbstract;
    
    { This controls @link(SearchLink) behavior, as described in
      [http://pasdoc.sipsolutions.net/LinkLookOption]. }
    property LinkLook: TLinkLook read FLinkLook write FLinkLook;
  end;

var
  ReservedWords: TStringList;


implementation

uses
  SysUtils,
  StreamUtils,
  Utils,
  PasDoc_Tokenizer;

{ ---------------------------------------------------------------------------- }
{ TDocGenerator                                                                }
{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.BuildLinks;

  procedure AssignLinks(MyUnit: TPasUnit; MyObject: TPasCio;
    const DocName: string; c: TPasItems);
  var
    i: Integer;
    p: TPasItem;
  begin
    if (not Assigned(c)) or (c.Count < 1) then Exit;
    for i := 0 to c.Count - 1 do begin
      p := c.PasItemAt[i];
      p.MyObject := MyObject;
      p.MyUnit := MyUnit;
      p.FullLink := CreateLink(p);
    end;
  end;

var
  CO: TPasCio;
  i: Integer;
  j: Integer;
  U: TPasUnit;
begin
  DoMessage(2, mtInformation, 'Creating links ...', []);
  if ObjectVectorIsNilOrEmpty(Units) then Exit;

  for i := 0 to Units.Count - 1 do begin
    U := Units.UnitAt[i];
    U.FullLink := CreateLink(U);
    U.OutputFileName := U.FullLink;
    
    for j := 0 to U.UsesUnits.Count - 1 do
    begin
      { Yes, this will also set U.UsesUnits.Objects[i] to nil
        if no such unit exists in Units table. }
      U.UsesUnits.Objects[j] := Units.FindName(U.UsesUnits[j]);
    end;

    AssignLinks(U, nil, U.FullLink, U.Constants);
    AssignLinks(U, nil, U.FullLink, U.Variables);
    AssignLinks(U, nil, U.FullLink, U.Types);
    AssignLinks(U, nil, U.FullLink, U.FuncsProcs);

    if not ObjectVectorIsNilOrEmpty(U.CIOs) then begin
      for j := 0 to U.CIOs.Count - 1 do begin
        CO := TPasCio(U.CIOs.PasItemAt[j]);
        CO.MyUnit := U;

        if not CO.WasDeserialized then begin
          CO.FullLink := CreateLink(CO);
          CO.OutputFileName := CO.FullLink;
        end;
        AssignLinks(U, CO, CO.FullLink, CO.Fields);
        AssignLinks(U, CO, CO.FullLink, CO.Methods);
        AssignLinks(U, CO, CO.FullLink, CO.Properties);
      end;
    end;
  end;
  DoMessage(2, mtInformation, '... ' + ' links created', []);
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.CloseStream;
begin
  if Assigned(FCurrentStream) then begin
    FCurrentStream.Free;
    FCurrentStream := nil;
  end;
end;

{ ---------------------------------------------------------------------------- }

function TDocGenerator.CreateLink(const Item: TPasItem): string;
begin
  Result := Item.Name;
end;

{ ---------------------------------------------------------------------------- }

function TDocGenerator.CreateStream(const AName: string;
  const AOverwrite: boolean): TCreateStreamResult;
begin
  CloseStream;
  DoMessage(4, mtInformation, 'Creating output stream "' + AName + '".', []);
  Result := csError;
  if FileExists(DestinationDirectory + AName) and not AOverwrite then begin
    Result := csExisted;
  end else begin
    try
      FCurrentStream := TFileStream.Create(DestinationDirectory+AName, fmCreate);
      Result := csCreated;
    except
    end;
  end;
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.HandleLongCodeTag(TagManager: TTagManager;
  const TagName, TagDesc: string; var ReplaceStr: string);
begin
  if TagDesc = '' then
    exit;
  // Trim off "marker" characters at the beginning and end of TagDesc.
  // Then trim or white space.
  // Then format pascal code.
  ReplaceStr := FormatPascalCode(Copy(TagDesc,2,Length(TagDesc)-2));
end;

procedure TDocGenerator.HandleHtmlTag(TagManager: TTagManager;
  const TagName, TagDesc: string; var ReplaceStr: string);
begin
  ReplaceStr := HtmlString(TagDesc);
end;

procedure TDocGenerator.HandleLatexTag(TagManager: TTagManager;
  const TagName, TagDesc: string; var ReplaceStr: string);
begin
  ReplaceStr := LatexString(TagDesc);
end;

procedure TDocGenerator.HandleNameTag(TagManager: TTagManager;
  const TagName, TagDesc: string; var ReplaceStr: string);
begin
  ReplaceStr := CodeString(ConvertString(FCurrentItem.Name));
end;

procedure TDocGenerator.HandleClassnameTag(TagManager: TTagManager;
  const TagName, TagDesc: string; var ReplaceStr: string);
begin
  if Assigned(fCurrentItem.MyObject) then begin
    ReplaceStr := CodeString(ConvertString(fCurrentItem.MyObject.Name));
  end else if fCurrentItem is TPasCio then begin
    ReplaceStr := CodeString(ConvertString(fCurrentItem.Name));
  end
end;

// handles @true, @false, @nil (Who uses these tags anyway?)
procedure TDocGenerator.HandleLiteralTag(TagManager: TTagManager;
  const TagName, TagDesc: string; var ReplaceStr: string);
begin
  ReplaceStr := CodeString(UpCase(TagName[1]) + Copy(TagName, 2, 255));
end;

procedure TDocGenerator.HandleInheritedTag(TagManager: TTagManager;
  const TagName, TagDesc: string; var ReplaceStr: string);
var
  TheObject: TPasCio;
  Ancestor: TPasItem;
  s: string;
  TheLink: string;
begin
  if Assigned(fCurrentItem.MyObject) then
    TheObject := fCurrentItem.MyObject
  else if fCurrentItem is TPasCio then
    TheObject := TPasCio(fCurrentItem)
  else
    TheObject := nil;

  // Try to find inherited property of item.
  // Updated 14 Jun 2002

   TheLink := '';
  if Assigned(TheObject)
    and not StringVectorIsNilOrEmpty(TheObject.Ancestors) then begin
    s := TheObject.Ancestors.FirstName;
    Ancestor := SearchItem(s, fCurrentItem);
    if Assigned(Ancestor) and (Ancestor.ClassType = TPasCio)
      then begin
      repeat
        if fCurrentItem.MyObject = nil then
          // we are looking for the ancestor itself
          TheLink := SearchLink(s, fCurrentItem, '')
        else
          // we are looking for an ancestor's property or method
          TheLink := SearchLink(s + '.' + fCurrentItem.Name, fCurrentItem, '');
        if TheLink <> '' then Break;

        if not StringVectorIsNilOrEmpty(TPasCio(Ancestor).Ancestors)
          then begin
          s := TPasCio(Ancestor).Ancestors.FirstName;
          Ancestor := SearchItem(s, Ancestor);
        end else begin
          Break;
        end;
      until Ancestor = nil;
    end;
  end;

  if TheLink <> '' then begin
    ReplaceStr := TheLink;
  end else begin
    DoMessage(2, mtWarning, 'Could not resolve "@Inherited" (%s)', [fCurrentItem.QualifiedName]);
    ReplaceStr := CodeString(ConvertString(fCurrentItem.Name));
  end;
end;

function TDocGenerator.SearchLinkOrWarning(const Identifier: string; 
  Item: TPasItem; const LinkDisplay: string;
  const WarningFormat: string): string;
begin
  Result := SearchLink(Identifier, Item, LinkDisplay);

  if Result = '' then
  begin
    DoMessage(1, mtWarning, WarningFormat, [Identifier, Item.QualifiedName]);
    Result := CodeString(ConvertString(Identifier));
  end;
end;

procedure TDocGenerator.HandleLinkTag(TagManager: TTagManager;
  const TagName, TagDesc: string; var ReplaceStr: string);
var LinkTarget, LinkDisplay: string;
begin
  ExtractFirstWord(TagDesc, LinkTarget, LinkDisplay);
  ReplaceStr := SearchLinkOrWarning(LinkTarget, FCurrentItem, LinkDisplay,
    'Could not resolve "@Link(%s)" (%s)');
end;

procedure TDocGenerator.HandleCodeTag(TagManager: TTagManager;
  const TagName, TagDesc: string; var ReplaceStr: string);
begin
  ReplaceStr := CodeString(TagDesc);
end;

procedure TDocGenerator.HandleBrTag(TagManager: TTagManager;
  const TagName, TagDesc: string; var ReplaceStr: string);
begin
  ReplaceStr := LineBreak;
end;

procedure TDocGenerator.DoMessageFromExpandDescription(
  const MessageType: TMessageType; const AMessage: string; 
  const AVerbosity: Cardinal);
begin
  if Assigned(OnMessage) then
    OnMessage(MessageType, AMessage + 
      ' (in description of "' + FCurrentItem.QualifiedName + '")', AVerbosity);    
end;

function TDocGenerator.ExpandDescription(Item: TPasItem; 
  const Description: string;
  WantFirstSentenceEnd: boolean;
  var FirstSentenceEnd: Integer): string;
var
  TagManager: TTagManager;
begin
  Assert(not Item.WasDeserialized);
  
  // make it available to the handlers
  FCurrentItem := Item;

  TagManager := TTagManager.Create;
  try
    TagManager.Abbreviations := Abbreviations;
    TagManager.ConvertString := {$IFDEF FPC}@{$ENDIF}ConvertString;
    TagManager.URLLink := {$IFDEF FPC}@{$ENDIF}URLLink;
    TagManager.OnMessage := {$IFDEF FPC}@{$ENDIF}DoMessageFromExpandDescription;
    TagManager.Paragraph := Paragraph;
    
    Item.RegisterTagHandlers(TagManager);

    { Tags without params }
    TagManager.AddHandler('classname',{$IFDEF FPC}@{$ENDIF} HandleClassnameTag, []);
    TagManager.AddHandler('true',{$IFDEF FPC}@{$ENDIF} HandleLiteralTag, []);
    TagManager.AddHandler('false',{$IFDEF FPC}@{$ENDIF} HandleLiteralTag, []);
    TagManager.AddHandler('nil',{$IFDEF FPC}@{$ENDIF} HandleLiteralTag, []);
    TagManager.AddHandler('inherited',{$IFDEF FPC}@{$ENDIF} HandleInheritedTag, []);
    TagManager.AddHandler('name',{$IFDEF FPC}@{$ENDIF} HandleNameTag, []);
    TagManager.AddHandler('br',{$IFDEF FPC}@{$ENDIF} HandleBrTag, []);

    { Tags with non-recursive params }
    TagManager.AddHandler('longcode',{$IFDEF FPC}@{$ENDIF} HandleLongCodeTag,
      [toParameterRequired]);
    TagManager.AddHandler('html',{$IFDEF FPC}@{$ENDIF} HandleHtmlTag,
      [toParameterRequired]);
    TagManager.AddHandler('latex',{$IFDEF FPC}@{$ENDIF} HandleLatexTag,
      [toParameterRequired]);
    TagManager.AddHandler('link',{$IFDEF FPC}@{$ENDIF} HandleLinkTag,
      [toParameterRequired]);

    { Tags with recursive params }
    TagManager.AddHandler('code',{$IFDEF FPC}@{$ENDIF} HandleCodeTag,
      [toParameterRequired, toRecursiveTags]);

    Result := TagManager.Execute(Description,
      WantFirstSentenceEnd, FirstSentenceEnd);
  finally
    TagManager.Free;
  end;
end;

function TDocGenerator.ExpandDescription(Item: TPasItem; 
  const Description: string): string; 
var Dummy: Integer;
begin
  Result := ExpandDescription(Item, Description, false, Dummy);
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.ExpandDescriptions;
  
  procedure ExpandCollection(c: TPasItems); forward;

  { expands Description and DetailedDescription of Item }
  procedure ExpandItem(Item: TPasItem);
  var FirstSentenceEnd: Integer;
  begin
    if Item = nil then Exit;

    Item.DetailedDescription := TrimCompress(
      ExpandDescription(Item, Item.DetailedDescription, true, FirstSentenceEnd));

    Item.AbstractDescriptionWasAutomatic := 
      AutoAbstract and (Trim(Item.AbstractDescription) = '');

    if Item.AbstractDescriptionWasAutomatic then
    begin
      Item.AbstractDescription := 
        Copy(Item.DetailedDescription, 1, FirstSentenceEnd);
      Item.DetailedDescription := 
        Copy(Item.DetailedDescription, FirstSentenceEnd + 1, MaxInt);
    end;

    if Item is TPasEnum then
      ExpandCollection(TPasEnum(Item).Members);
  end;

  { for all items in collection C, expands descriptions }
  procedure ExpandCollection(c: TPasItems);
  var
    i: Integer;
  begin
    if c = nil then Exit;
    for i := 0 to c.Count - 1 do 
      ExpandItem(c.PasItemAt[i]);
  end;

var
  CO: TPasCio;
  i: Integer;
  j: Integer;
  U: TPasUnit;
begin
  DoMessage(2, mtInformation, 'Expanding descriptions ...', []);

  if ObjectVectorIsNilOrEmpty(Units) then Exit;

  for i := 0 to Units.Count - 1 do begin
    U := Units.UnitAt[i];
    if U.WasDeserialized then continue;
    ExpandItem(U);
    ExpandCollection(U.Constants);
    ExpandCollection(U.Variables);
    ExpandCollection(U.Types);
    ExpandCollection(U.FuncsProcs);

    if not ObjectVectorIsNilOrEmpty(U.CIOs) then
      for j := 0 to U.CIOs.Count - 1 do begin
        CO := TPasCio(U.CIOs.PasItemAt[j]);
        ExpandItem(CO);
        ExpandCollection(CO.Fields);
        ExpandCollection(CO.Methods);
        ExpandCollection(CO.Properties);
      end;
  end;

  DoMessage(2, mtInformation, '... Descriptions expanded', []);
end;

{ ---------------------------------------------------------------------------- }

function TDocGenerator.ExtractEmailAddress(s: string; var S1, S2,
  EmailAddress: string): Boolean;
const
  ALLOWED_CHARS = ['a'..'z', 'A'..'Z', '-', '.', '_', '0'..'9'];
  Letters = ['a'..'z', 'A'..'Z'];
var
  atPos: Integer;
  i: Integer;
begin
  Result := False;
  if (Length(s) < 6) { minimum length of email address: a@b.cd } then Exit;
  atPos := Pos('@', s);
  if (atPos < 2) or (atPos > Length(s) - 3) then Exit;
  { assemble address left of @ }
  i := atPos - 1;
  while (i >= 1) and (s[i] in ALLOWED_CHARS) do
    Dec(i);
  EmailAddress := System.Copy(s, i + 1, atPos - i - 1) + '@';
  S1 := '';
  if (i > 1) then S1 := System.Copy(s, 1, i);
  { assemble address right of @ }
  i := atPos + 1;
  while (i <= Length(s)) and (s[i] in ALLOWED_CHARS) do
    Inc(i);
  EmailAddress := EmailAddress + System.Copy(s, atPos + 1, i - atPos - 1);
  if (Length(EmailAddress) < 6) or
    (not (EmailAddress[Length(EmailAddress)] in Letters)) or
  (not (EmailAddress[Length(EmailAddress) - 1] in Letters)) then Exit;
  S2 := '';
  if (i <= Length(s)) then S2 := System.Copy(s, i, Length(s) - i + 1);
  Result := True;
end;

{ ---------------------------------------------------------------------------- }

function TDocGenerator.FindGlobal(const S1, S2, S3: string; const n: Integer): TPasItem;
var
  i: Integer;
  Item: TPasItem;
  U: TPasUnit;
begin
  Result := nil;

  if ObjectVectorIsNilOrEmpty(Units) then Exit;
  
  case n of
    0: for i := 0 to Units.Count - 1 do
       begin
         U := Units.UnitAt[i];

         if SameText(U.Name, S1) then
         begin
           Result := U;
           Exit;
         end;

         Result := U.FindItem(S1);
         if Result <> nil then Exit;
       end;
    1: begin
         { object.field_method_property }
         for i := 0 to Units.Count - 1 do begin
           Result := Units.UnitAt[i].FindFieldMethodProperty(S1, S2);
           if Assigned(Result) then Exit;
         end;

         { unit.cio_var_const_type }
         U := TPasUnit(Units.FindName(S1));
         if Assigned(U) then 
           Result := U.FindItem(S2);
       end;
    2: begin
         { unit.objectorclassorinterface.fieldormethodorproperty } 
         U := TPasUnit(Units.FindName(S1));
         if (not Assigned(U)) then Exit;
         Item := U.FindItem(S2);
         if (not Assigned(Item)) then Exit;
         Item := Item.FindItem(S3);
         if (not Assigned(Item)) then Exit;
         Result := Item;
         Exit;
       end;
  end;
end;

{ ---------------------------------------------------------------------------- }

function TDocGenerator.GetCIOTypeName(MyType: TCIOType): string;
begin
  case MyType of
    CIO_CLASS: Result := FLanguage.Translation[trClass];
    CIO_SPINTERFACE: Result := FLanguage.Translation[trDispInterface];
    CIO_INTERFACE: Result := FLanguage.Translation[trInterface];
    CIO_OBJECT: Result := FLanguage.Translation[trObject];
    CIO_RECORD: Result := 'record'; // TODO
    CIO_PACKEDRECORD: Result := 'packed record'; // TODO
  else
    Result := '';
  end;
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.LoadDescriptionFile(n: string);
var
  f           : TStream;
  ItemName    : string;
  Description : string;
  i           : Integer;
  s           : string;
const
  IdentChars  = ['A'..'Z', 'a'..'z', '_', '.', '0'..'9'];
begin
  ItemName := '';
  if n = '' then Exit;
  try
    f := TFileStream.Create(n, fmOpenRead);
  
    Assert(Assigned(f));
  
    try
      while f.Position < f.Size do begin
        s := StreamReadLine(f);
        if s[1] = '#' then begin
          i := 2;
          while s[i] in [' ', #9] do Inc(i);
          { Make sure we read a valid name - the user might have used # in his
            description. }
          if s[i] in IdentChars then begin
            if ItemName <> '' then StoreDescription(ItemName, Description);
            { Read item name and beginning of the description }
            ItemName := '';
            repeat
              ItemName := ItemName + s[i];
              Inc(i);
            until not (s[i] in IdentChars);
            while s[i] in [' ', #9] do Inc(i);
            Description := Copy(s, i, MaxInt);
            Continue;
          end;
        end;
        Description := Description + s;
      end;
      
      if ItemName = '' then
        DoMessage(2, mtWarning, 'No descriptions read from "%s" -- invalid or empty file', [n])
      else
        StoreDescription(ItemName, Description);
    finally
      f.Free;
    end;
  except
    DoError('Could not open description file "%s".', [n], 0);
  end;
end; {TDocGenerator.LoadDescriptionFile}

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.LoadDescriptionFiles(const c: TStringVector);
var
  i: Integer;
begin
  if c <> nil then begin
    DoMessage(3, mtInformation, 'Loading description files ...', []);
    for i := 0 to c.Count - 1 do
      LoadDescriptionFile(c[i]);
  end;
end;

{ ---------------------------------------------------------------------------- }

function TDocGenerator.SearchItem(s: string; const Item: TPasItem): TPasItem;
var
  n: Integer;
  S1: string;
  S2: string;
  S3: string;
begin
  { S is supposed to have 0 to 2 dots in it - S1, S2 and S3 contain
    the parts between the dots, N the number of dots }
  if (not SplitLink(s, S1, S2, S3, n)) then begin
    DoMessage(2, mtWarning, 'The link "' + s + '" is invalid', []);
    Result := nil;
    Exit;
  end;

  { first try to find link starting at Item }
  if Assigned(Item) then begin
    Result := Item.FindName(S1, S2, S3, n);
  end
  else
    Result := nil;

  if not Assigned(Result) then Result := FindGlobal(S1, S2, S3, n);
end;

{ ---------------------------------------------------------------------------- }

function TDocGenerator.SearchLink(s: string; const Item: TPasItem;
  const LinkDisplay: string): string;
var
  n: Integer;
  S1: string;
  S2: string;
  S3: string;
  FoundItem: TPasItem;
begin
  { S is supposed to have 0 to 2 dots in it - S1, S2 and S3 contain
    the parts between the dots, N the number of dots }
  if (not SplitLink(s, S1, S2, S3, n)) then begin
    if Item.MyUnit = nil then
      DoMessage(2, mtWarning, 'Invalid Link "' + s + '" (' + Item.Name + ')', [])
    else
      DoMessage(2, mtWarning, 'Invalid Link "' + s + '" (' + Item.MyUnit.Name + '.' + Item.Name + ')', []);
    Result := 'UNKNOWN';
    Exit;
  end;

  { first try to find link starting at Item }
  FoundItem := nil;
  if Assigned(Item) then begin
    FoundItem := Item.FindName(S1, S2, S3, n);
  end;

  { Find Global }
  if FoundItem = nil then
    FoundItem := FindGlobal(S1, S2, S3, n);

  if Assigned(FoundItem) then
  begin
    if LinkDisplay <> '' then
      Result := CreateReferencedLink(LinkDisplay, FoundItem.FullLink) else
    case LinkLook of
      llDefault:
        Result := CreateReferencedLink(S, FoundItem.FullLink);
      llStripped: 
        Result := CreateReferencedLink(FoundItem.Name, FoundItem.FullLink);
      llFull:
        begin
          Result := CreateReferencedLink(FoundItem.Name, FoundItem.FullLink);
          
          if S3 <> '' then
          begin
            FoundItem := FindGlobal(S1, S2, '', 1);
            Result := CreateReferencedLink(FoundItem.Name,FoundItem.FullLink) + '.' + Result;
          end;

          if S2 <> '' then
          begin
            FoundItem := FindGlobal(S1, '', '', 0);
            Result := CreateReferencedLink(FoundItem.Name,FoundItem.FullLink) + '.' + Result;
          end;          
        end;
      else Assert(false, 'LinkLook = ??');
    end;
  end else
    Result := '';
end;

{ ---------------------------------------------------------------------------- }

function TDocGenerator.SplitLink(s: string; var S1, S2, S3: string;
  var n: Integer): Boolean;

  procedure SplitInTwo(s: string; var S1, S2: string);
  var
    i: Integer;
  begin
    i := Pos('.', s);
    if (i = 0) then begin
      S1 := s;
      S2 := '';
    end
    else begin
      S1 := System.Copy(s, 1, i - 1);
      S2 := System.Copy(s, i + 1, Length(s));
    end;
  end;

var
  i: Integer;
  t: string;
begin
  Result := False;
  S1 := '';
  S2 := '';
  S3 := '';
  n := 0;
  {  I := 1;}
  s := Trim(s);
  if (Length(s) = 0) then Exit;
  if (not (s[1] in IdentifierStart)) then Exit;
  i := 2;
  while (i <= Length(s)) do begin
    if (not (s[i] in IdentifierOther)) then Exit;
    Inc(i);
  end;
  SplitInTwo(s, S1, S2);
  if (Length(S2) = 0) then begin
    n := 0;
  end
  else begin
    t := S2;
    SplitInTwo(t, S2, S3);
    if (Length(S3) = 0) then
      n := 1
    else
      n := 2;
  end;
  Result := True;
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.StoreDescription(ItemName: string; var t: string);
var
  Item: TPasItem;
  n: Integer;
  S1: string;
  S2: string;
  S3: string;
begin
  if t = '' then Exit;

  DoMessage(5, mtInformation, 'Storing description for ' + ItemName, []);
  if SplitLink(ItemName, S1, S2, S3, n) then begin
    Item := FindGlobal(S1, S2, S3, n);
    if Assigned(Item) then begin
      if Item.DetailedDescription <> '' then begin
        DoMessage(2, mtWarning, 'More than one description for ' + ItemName,
          []);
        t := '';
      end else begin
        Item.DetailedDescription := t;
      end;
    end else begin
      DoMessage(2, mtWarning, 'Could not find item ' + ItemName, []);
      t := '';
    end;
  end else begin
    DoMessage(2, mtWarning, 'Could not split item "' + ItemName + '"', []);
  end;
  t := '';
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.WriteCIOs(HL: integer; c: TPasItems);
var
  i: Integer;
begin
  if ObjectVectorIsNilOrEmpty(c) then Exit;
  for i := 0 to c.Count - 1 do
    WriteCIO(HL, TPasCio(c.PasItemAt[i]));
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.WriteCIOSummary(HL: integer; c: TPasItems);
begin
  WriteItems(HL, FLanguage.Translation[trSummaryCio], 'Classes', c);
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.WriteConstants(HL: integer; c: TPasItems);
begin
  WriteItems(HL, FLanguage.Translation[trConstants], 'Constants', c);
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.WriteDescription(HL: integer; const Heading: string;
  const Item: TPasItem);
begin
  if Length(Heading) > 0 then WriteHeading(HL, Heading);
  WriteDirect(Item.GetDescription);
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.WriteConverted(const s: string; Newline: boolean);
begin
  WriteDirect(ConvertString(s), Newline);
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.WriteDirect(const t: string; Newline: boolean);
begin
  if length(t) > 0 then
    CurrentStream.WriteBuffer(t[1], Length(t));
  if Newline then
    StreamUtils.WriteLine(CurrentStream, '');
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.WriteTypes(const HL: integer; const t: TPasItems);
begin
  WriteItems(HL, FLanguage.Translation[trTypes], 'Types', t);
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.WriteUnits(const HL: integer);
var
  i: Integer;
begin
  if ObjectVectorIsNilOrEmpty(Units) then Exit;
  for i := 0 to Units.Count - 1 do begin
    WriteUnit(HL, Units.UnitAt[i]);
  end;
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.WriteVariables(const HL: integer; const V: TPasItems);
begin
  WriteItems(HL, FLanguage.Translation[trVariables], 'Variables', V);
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.DoError(const AMessage: string; const AArguments:
  array of const; const AExitCode: Word);
begin
  raise EPasDoc.Create(AMessage, AArguments, AExitCode);
end;

{ ---------------------------------------------------------------------------- }

procedure TDocGenerator.DoMessage(const AVerbosity: Cardinal; const
  MessageType: TMessageType; const AMessage: string; const AArguments: array of
  const);
begin
  if Assigned(FOnMessage) then begin
    FOnMessage(MessageType, Format(AMessage, AArguments), AVerbosity);
  end;
end;

constructor TDocGenerator.Create(AOwner: TComponent);
begin
  inherited;
  FClassHierarchy := nil;
  FNoGeneratorInfo := False;
  FLanguage := TPasDocLanguages.Create;
  FAbbreviations := TStringList.Create;
  FAbbreviations.Duplicates := dupIgnore;
end;

procedure TDocGenerator.CreateClassHierarchy;
var
  unitLoop: Integer;
  classLoop: Integer;
  PU: TPasUnit;
  ACIO: TPasCio;
  ParentItem: TPasItem;
  Parent, Child: TPasItemNode;
begin
  FClassHierarchy.Free;
  FClassHierarchy := TStringCardinalTree.Create;
  for unitLoop := 0 to Units.Count - 1 do begin
    PU := Units.UnitAt[unitLoop];
    if PU.CIOs = nil then Continue;
    for classLoop := 0 to PU.CIOs.Count - 1 do begin
      ACIO := TPasCio(PU.CIOs.PasItemAt[classLoop]);
      if ACIO.MyType in CIO_NonHierarchy then continue;

      if Assigned(ACIO.Ancestors) and (ACIO.Ancestors.Count > 0) then begin
        ParentItem := FindGlobal(ACIO.Ancestors.FirstName, '', '', 0);
        if Assigned(ParentItem) then begin
          Parent := FClassHierarchy.ItemOfName(ParentItem.Name);
          // Add parent if not already there.
          if Parent = nil then begin
            Parent := FClassHierarchy.InsertItem(ParentItem);
          end;
        end else begin
          Parent := FClassHierarchy.ItemOfName(ACIO.Ancestors.FirstName);
          if Parent = nil then begin
            Parent := FClassHierarchy.InsertName(ACIO.Ancestors.FirstName);
          end;
        end;
      end else begin
        Parent := nil;
      end;

      Child := FClassHierarchy.ItemOfName(ACIO.Name);
      if Child = nil then begin
        FClassHierarchy.InsertItemParented(Parent, ACIO)
      end else begin
        if Parent <> nil then begin
          FClassHierarchy.MoveChildLast(Child, Parent);
        end;
      end;
    end;
  end;
  FClassHierarchy.Sort;
end;

destructor TDocGenerator.Destroy;
begin
  FLanguage.Free;
  FClassHierarchy.Free;
  FAbbreviations.Free;
  FCurrentStream.Free;
  inherited;
end;

procedure TDocGenerator.WriteEndOfCode;
begin
// nothing - for some output this is irrelevant
end;

procedure TDocGenerator.WriteStartOfCode;
begin
// nothing - for some output this is irrelevant
end;

procedure TDocGenerator.WriteDocumentation;
begin
  if OutputGraphVizUses then WriteGVUses;
  if OutputGraphVizClassHierarchy then WriteGVClasses;
end;

procedure TDocGenerator.SetLanguage(const Value: TLanguageID);
begin
  FLanguage.Language := Value;
end;

procedure TDocGenerator.SetDestDir(const Value: string);
begin
  if Value <> '' then begin
    FDestDir := IncludeTrailingPathDelimiter(Value);
  end else begin
    FDestDir := '';
  end;
end;

function TDocGenerator.GetLanguage: TLanguageID;
begin
  Result := FLanguage.Language;
end;

procedure TDocGenerator.WriteGVClasses;
var
  LNode: TPasItemNode;

begin
  CreateClassHierarchy;
  LNode := FClassHierarchy.FirstItem;
  if Assigned(LNode) then begin
    if CreateStream(OverviewFilenames[9] + '.dot', True) = csError
      then begin
        DoMessage(1, mtError, 'Could not create output file "%s.dot".', [OverviewFilenames[9]]);
        Exit;
    end;
    WriteDirect('DiGraph Classes {', true);
    while Assigned(LNode) do begin
      if Assigned(LNode.Parent) then begin
        if Length(LNode.Parent.Name) > 0 then begin
          WriteDirect('  '+LNode.Name + ' -> '+LNode.Parent.Name, true);
        end;
      end;
      LNode := FClassHierarchy.NextItem(LNode);
    end;

    WriteDirect('}', true);
    CloseStream;
  end;
end;

procedure TDocGenerator.WriteGVUses;
var
  i, j: Integer;
  U: TPasUnit;
begin
  if not ObjectVectorIsNilOrEmpty(FUnits) then begin
    if CreateStream(OverviewFilenames[8]+'.dot', True) = csError
      then begin
        DoMessage(1, mtError, 'Could not create output file "%s.dot".', [OverviewFilenames[8]]);
        Exit;
    end;
    WriteDirect('DiGraph Uses {', true);
    for i := 0 to FUnits.Count-1 do begin
      if FUnits.PasItemAt[i] is TPasUnit then begin
        U := TPasUnit(FUnits.PasItemAt[i]);
        if not StringVectorIsNilOrEmpty(U.UsesUnits) then begin
          for j := 0 to U.UsesUnits.Count-1 do begin
            WriteDirect('  '+U.Name+' -> '+U.UsesUnits[j], true);
          end;
        end;
      end;
    end;
    WriteDirect('}', true);
    CloseStream;
  end;
end;

procedure TDocGenerator.SetAbbreviations(const Value: TStringList);
begin
  FAbbreviations.Assign(Value);
end;

procedure TDocGenerator.ParseAbbreviationsFile(const AFileName: string);
var
  L: TStringList;
  i, p: Integer;
  s, lname, value: string;
begin
  if FileExists(AFileName) then begin
    L := TStringList.Create;
    try
      L.LoadFromFile(AFileName);
      for i := 0 to L.Count-1 do begin
        s := Trim(L[i]);
        if length(s)>0 then begin
          if s[1] = '[' then begin
            p := pos(']', s);
            if p>=0 then begin
              lname := Trim(copy(s, 2, p-2));
              value := Trim(copy(s,p+1,MaxInt));
              FAbbreviations.Values[lname] := value;
            end;
          end;
        end;
      end;
    finally
      L.Free;
    end;
  end;
end;

procedure TDocGenerator.CheckString(const AString: string;
  const AErrors: TObjectVector);
var
  s: string;
  p, p2: Integer;
  LError: TSpellingError;
begin
  AErrors.Clear;
  if FCheckSpelling and FSpellCheckStarted then begin
    s := StringReplace(AString, #10, ' ', [rfReplaceAll]);
    s := StringReplace(AString, #13, ' ', [rfReplaceAll]);
    if Length(FAspellMode) > 0 then begin
      PasDoc_RunHelp.WriteLine('-', FAspellPipe);
      PasDoc_RunHelp.WriteLine('+'+FAspellMode, FAspellPipe);
    end;
    PasDoc_RunHelp.WriteLine('^'+s, FAspellPipe);
    s := ReadLine(FAspellPipe);
    while Length(s) > 0 do begin
      case s[1] of
        '*': continue; // no error
        '#': begin
               LError := TSpellingError.Create; 
               s := copy(s, 3, MaxInt); // get rid of '# '
               p := Pos(' ', s);
               LError.Word := copy(s, 1, p-1); // get word
               LError.Suggestions := '';
               s := copy(s, p+1, MaxInt);
               LError.Offset := StrToIntDef(s, 0)-1;
               DoMessage(2, mtWarning, 'possible spelling error for word "%s"', [LError.Word]);
               AErrors.Add(LError);
             end;
        '&': begin
               LError := TSpellingError.Create; 
               s := copy(s, 3, MaxInt); // get rid of '& '
               p := Pos(' ', s);
               LError.Word := copy(s, 1, p-1); // get word
               s := copy(s, p+1, MaxInt);
               p := Pos(' ', s);
               s := copy(s, p+1, MaxInt);
               p2 := Pos(':', s);
               LError.Suggestions := Copy(s, Pos(':', s)+2, MaxInt);
               SetLength(s, p2-1);
               LError.Offset := StrToIntDef(s, 0)-1;
               DoMessage(2, mtWarning, 'possible spelling error for word "%s"', [LError.Word]);
               AErrors.Add(LError);
             end;
      end;
      s := ReadLine(FAspellPipe);
    end;
  end;
end;

procedure TDocGenerator.EndSpellChecking;
begin
  if FCheckSpelling and FSpellCheckStarted then begin
    CloseProgram(FAspellPipe);
  end;
end;

procedure TDocGenerator.StartSpellChecking(const AMode: string);
var
  s: string;
  L: TStringList;
  i: Integer;
begin
  FSpellCheckStarted := False;
  if FCheckSpelling then begin
    try
      FAspellMode := AMode;
      if AMode <> '' then begin
        FAspellPipe := RunProgram('/usr/bin/aspell', '-a --lang='+FAspellLanguage+' --mode='+AMode);
      end else begin
        FAspellPipe := RunProgram('/usr/bin/aspell', '-a --lang='+FAspellLanguage);
      end;
      FSpellCheckStarted := True;
    except
      DoMessage(1, mtWarning, 'spell checking is not supported yet, disabling', []);
      FSpellCheckStarted := False;
    end;
    s := ReadLine(FAspellPipe);
    if copy(s,1,4) <> '@(#)' then begin
      CloseProgram(FAspellPipe);
      FSpellCheckStarted := False;
      DoError('Could not initialize aspell: "%s"', [s], 1);
    end else begin
      PasDoc_RunHelp.WriteLine('!', FAspellPipe);
      if Length(IgnoreWordsFile)>0 then begin
        L := TStringList.Create;
        try
          L.LoadFromFile(IgnoreWordsFile);
          for i := L.Count-1 downto 0 do begin
            PasDoc_RunHelp.WriteLine('@'+L[i], FAspellPipe);
          end;
        except
          DoMessage(1, mtWarning, 'Could not load ignore words file %s', [IgnoreWordsFile]);
        end;
        L.Free;
      end;
    end;
  end;
end;

function TDocGenerator.ParameterString(const ParamType,
  Param: string): string;
begin
  Result := #10 + ParamType + ' ' + Param;
end;

procedure TDocGenerator.WriteDirect(const t: string);
begin
  WriteDirect(t, false);
end;

procedure TDocGenerator.WriteConverted(const s: string);
begin
  WriteConverted(s, false);
end;

function TDocGenerator.FormatPascalCode(const Line: string): string;
var
  CharIndex: integer;
  CodeType: TCodeType;
  CommentBegining: integer;
  StringBeginning: integer;
  CodeBeginning: integer;
  EndOfCode: boolean;
  WhiteSpaceBeginning: integer;
const
  Separators = [' ', ',', '(', ')', #9, #10, #13, ';', '[', ']', '{', '}',
    '''', ':', '<', '>', '=', '+', '-', '*', '/', '@', '.'];
  LineEnd = [#10, #13];
  AlphaNumeric = ['0'..'9', 'a'..'z', 'A'..'Z'];
  function TestCommentStart: boolean;
  begin
    result := False;
    if Line[CharIndex] = '(' then
    begin
      if (CharIndex < Length(Line)) and (Line[CharIndex + 1] = '*') then
      begin
        CodeType := ctParenComment;
        result := True;
      end
    end
    else if Line[CharIndex] = '{' then
    begin
      if (CharIndex < Length(Line)) and (Line[CharIndex + 1] = '$') then
      begin
        CodeType := ctCompilerComment;
      end
      else
      begin
        CodeType := ctBracketComment;
      end;
      result := True;
    end
    else if Line[CharIndex] = '/' then
    begin
      if (CharIndex < Length(Line)) and (Line[CharIndex + 1] = '/') then
      begin
        CodeType := ctSlashComment;
        result := True;
      end
    end;
    if result then
    begin
      CommentBegining := CharIndex;
    end;
  end;
  function TestStringBeginning: boolean;
  begin
    result := False;
    if Line[CharIndex] = '''' then
    begin
      if CodeType <> ctChar then
      begin
        StringBeginning := CharIndex;
      end;
      CodeType := ctString;
      result := True;
    end
  end;
begin
  CommentBegining := 1;
  StringBeginning := 1;
  result := '';
  CodeType := ctWhiteSpace;
  WhiteSpaceBeginning := 1;
  CodeBeginning := 1;
  for CharIndex := 1 to Length(Line) do
  begin
    case CodeType of
      ctWhiteSpace:
        begin
          EndOfCode := False;
          if TestStringBeginning then
          begin
            EndOfCode := True;
          end
          else if Line[CharIndex] = '#' then
          begin
            StringBeginning := CharIndex;
            CodeType := ctChar;
            EndOfCode := True;
          end
          else if TestCommentStart then
          begin
            EndOfCode := True;
          end
          else if Line[CharIndex] in AlphaNumeric then
          begin
            CodeType := ctCode;
            CodeBeginning := CharIndex;
            EndOfCode := True;
          end;
          if EndOfCode then
          begin
            result := result + (Copy(Line, WhiteSpaceBeginning, CharIndex -
              WhiteSpaceBeginning));
          end;
        end;
      ctString:
        begin
          if Line[CharIndex] = '''' then
          begin
            if (CharIndex = Length(Line)) or (Line[CharIndex + 1] <> '''') then
            begin
              CodeType := ctEndString;
              result := result + FormatString(Copy(Line, StringBeginning,
                CharIndex - StringBeginning + 1));
            end;
          end;
        end;
      ctCode:
        begin
          EndOfCode := False;
          if TestStringBeginning then
          begin
            EndOfCode := True;
          end
          else if Line[CharIndex] = '#' then
          begin
            EndOfCode := True;
            CodeType := ctChar;
            StringBeginning := CharIndex;
          end
          else if TestCommentStart then
          begin
            EndOfCode := True;
          end
          else if not (Line[CharIndex] in AlphaNumeric) then
          begin
            EndOfCode := True;
            CodeType := ctWhiteSpace;
            WhiteSpaceBeginning := CharIndex;
          end;
          if EndOfCode then
          begin
            result := result + FormatCode(Copy(Line, CodeBeginning, CharIndex -
              CodeBeginning));
          end;
        end;
      ctEndString:
        begin
          if Line[CharIndex] = '#' then
          begin
            CodeType := ctChar;
          end
          else if TestCommentStart then
          begin
            // do nothing
          end
          else if Line[CharIndex] in AlphaNumeric then
          begin
            CodeType := ctCode;
            CodeBeginning := CharIndex;
          end
          else
          begin
            CodeType := ctWhiteSpace;
            WhiteSpaceBeginning := CharIndex;
          end;
        end;
      ctChar:
        begin
          if Line[CharIndex] = '''' then
          begin
            CodeType := ctString;
          end
          else if TestCommentStart then
          begin
            // do nothing
          end
          else if Line[CharIndex] in Separators then
          begin
            result := result + FormatString(Copy(Line, StringBeginning,
              CharIndex - StringBeginning));
            CodeType := ctWhiteSpace;
            WhiteSpaceBeginning := CharIndex;
          end;
        end;
      ctParenComment:
        begin
          if Line[CharIndex] = ')' then
          begin
            if (CharIndex > 1) and (Line[CharIndex - 1] = '*') then
            begin
              CodeType := ctEndComment;
              result := result + FormatComment(Copy(Line, CommentBegining,
                CharIndex - CommentBegining + 1));
            end;
          end;
        end;
      ctBracketComment:
        begin
          if Line[CharIndex] = '}' then
          begin
            CodeType := ctEndComment;
            result := result + FormatComment(Copy(Line, CommentBegining,
              CharIndex - CommentBegining + 1));
          end;
        end;
      ctCompilerComment:
        begin
          if Line[CharIndex] = '}' then
          begin
            CodeType := ctEndComment;
            result := result + FormatCompilerComment(Copy(Line, CommentBegining,
              CharIndex - CommentBegining + 1));
          end;
        end;
      ctSlashComment:
        begin
          if Line[CharIndex] in LineEnd then
          begin
            CodeType := ctWhiteSpace;
            result := result + FormatComment(Copy(Line, CommentBegining,
              CharIndex - CommentBegining));
            WhiteSpaceBeginning := CharIndex;
          end;
        end;
      ctEndComment:
        begin
          if TestCommentStart then
          begin
            // do nothing
          end
          else if Line[CharIndex] in Separators then
          begin
            CodeType := ctWhiteSpace;
            WhiteSpaceBeginning := CharIndex;
          end
          else if Line[CharIndex] in AlphaNumeric then
          begin
            CodeType := ctCode;
            CodeBeginning := CharIndex;
          end;
        end;
    else
      Assert(False);
    end;
  end;
  CharIndex := Length(Line);
  case CodeType of
    ctWhiteSpace:
      begin
        result := result + (Copy(Line, WhiteSpaceBeginning, CharIndex -
          WhiteSpaceBeginning));
      end;
    ctString:
      begin
      end;
    ctCode:
      begin
        result := result + FormatCode(Copy(Line, CodeBeginning, CharIndex -
          CodeBeginning));
      end;
    ctEndString:
      begin
      end;
    ctChar:
      begin
        result := result + FormatString(Copy(Line, StringBeginning,
          CharIndex - StringBeginning));
      end;
    ctParenComment:
      begin
        result := result + FormatComment(Copy(Line, CommentBegining,
          CharIndex - CommentBegining + 1));
      end;
    ctBracketComment:
      begin
        result := result + FormatComment(Copy(Line, CommentBegining,
          CharIndex - CommentBegining + 1));
      end;
    ctCompilerComment:
      begin
        result := result + FormatCompilerComment(Copy(Line, CommentBegining,
          CharIndex - CommentBegining + 1));
      end;
    ctSlashComment:
      begin
      end;
    ctEndComment:
      begin
        result := result + FormatComment(Copy(Line, CommentBegining,
          CharIndex - CommentBegining + 1));
      end;
  else Assert(False);
  end;
end;

function TDocGenerator.FormatCode(AString: string): string;
begin
  if ReservedWords.IndexOf(LowerCase(AString)) >= 0 then
  begin
    Result := FormatKeyWord(AString);
  end
  else
  begin
    result := AString;
  end;
end;

function TDocGenerator.FormatComment(AString: string): string;
begin
  result := AString;
end;

function TDocGenerator.FormatCompilerComment(AString: string): string;
begin
  result := AString;
end;

function TDocGenerator.FormatKeyWord(AString: string): string;
begin
  result := AString;
end;

function TDocGenerator.FormatString(AString: string): string;
begin
  result := AString;
end;

function TDocGenerator.Paragraph: string; 
begin
  Result := ' ';
end;

function TDocGenerator.HtmlString(const S: string): string;
begin
  Result := '';
end;

function TDocGenerator.LatexString(const S: string): string;
begin
  Result := '';
end;

function TDocGenerator.LineBreak: string; 
begin
  Result := '';
end;

function TDocGenerator.URLLink(const URL: string): string; 
begin
  Result := ConvertString(URL);
end;

procedure TDocGenerator.WriteCodeWithLinksCommon(const p: TPasItem; 
  const Code: string; const ItemLink: string;
  const NameLinkBegin, NameLinkEnd: string;
  WriteLink: TWriteLinkProc);

  { Tries to find a link from string S. 
    Tries to split S using SplitLink, if succeeds then tries using p.FindName,
    if that does not resolve the link then tries using FindGlobal.
    
    Returns nil if S couldn't be resolved. 
    
    TODO -- this should be merged with @link(SearchLink) method
    for clarity. But this should never display a warning for user. }
  function DoSearchForLink(const S: string): TPasItem;
  var
    S1: string;
    S2: string;
    S3: string;
    n: Integer;
  begin
    if SplitLink(s, S1, S2, S3, n) then 
    begin
      Result := p.FindName(S1, S2, S3, n);
      if not Assigned(Result) then
        Result := FindGlobal(S1, S2, S3, n);
    end else
      Result := nil;
  end;

var
  NameFound, SearchForLink: Boolean;
  FoundItem: TPasItem;
  i, j, l: Integer;
  s: string;
  pl: TStandardDirective;  
  { ncstart marks what part of Code was already written:
    Code[1..ncstart - 1] is already written to output stream. }
  ncstart: Integer;
begin
  WriteStartOfCode;
  i := 1;
  NameFound := false;
  SearchForLink := False;
  l := Length(Code);
  ncstart := i;
  while i <= l do begin
    case Code[i] of
      '_', 'A'..'Z', 'a'..'z': 
        begin
          WriteConverted(Copy(Code, ncstart, i - ncstart));
          { assemble item }
          j := i;
          repeat
            Inc(i);
          until (i > l) or 
            (not (Code[i] in ['.', '_', '0'..'9', 'A'..'Z', 'a'..'z']));
          s := Copy(Code, j, i - j);

          if not NameFound and (s = p.Name) then 
          begin
            WriteDirect(NameLinkBegin);
            if ItemLink <> '' then
              WriteLink(ItemLink, ConvertString(s), '') else
              WriteConverted(s);
            WriteDirect(NameLinkEnd);
            NameFound := True;
          end else
          begin
            { Special processing for standard directives.
            
              Note that we check whether S is standard directive *after*
              we checked whether S matches P.Name, otherwise we would
              mistakenly think that 'register' is a standard directive
              in Code
                'procedure Register;'
              This shouldn't cause another problem (accidentaly
              making standard directive a link, e.g. in code like
                'procedure Foo; register'
              or even
                'procedure Register; register;'
              ) because we safeguard against it using NameFound and 
              SearchForLink state variables.
              
              That said, WriteCodeWithLinksCommon still remains a hackish 
              excuse to not implement a real Pascal parser logic...
              Improve this if you know how. }
              
            pl := StandardDirectiveByName(s);
            case pl of
              SD_ABSTRACT, SD_ASSEMBLER, SD_CDECL, SD_DYNAMIC, SD_EXPORT,
                SD_FAR, SD_FORWARD, SD_NAME, SD_NEAR, SD_OVERLOAD, SD_OVERRIDE,
                SD_PASCAL, SD_REGISTER, SD_SAFECALL, SD_STDCALL, SD_REINTRODUCE, SD_VIRTUAL:
                begin
                  WriteConverted(s);
                  SearchForLink := False;
                end;
              SD_EXTERNAL:
                begin
                  WriteConverted(s);
                  SearchForLink := true;
                end;
              else
                begin
                  if SearchForLink then
                    FoundItem := DoSearchForLink(S) else
                    FoundItem := nil;

                  if Assigned(FoundItem) then
                    WriteLink(FoundItem.FullLink, ConvertString(s), '') else
                    WriteConverted(s);
                end;
            end;
          end;
          
          ncstart := i;          
        end;
      ':', '=': 
        begin
          SearchForLink := True;
          Inc(i);
        end;
      ';':
        begin
          SearchForLink := False;
          Inc(i);
        end;
      '''':
        begin
          { No need to worry here about the fact that 'foo''bar' is actually
            one string, "foo'bar". We will parse it in this procedure as
            two strings, 'foo', then 'bar' (missing the fact that ' is
            a part of string), but this doesn't harm us (as we don't
            need here the value of parsed string). }
          repeat
            Inc(i);
          until (i > l) or (Code[i] = '''');
          Inc(i);
        end;
      else Inc(i);
    end;
  end;
  WriteConverted(Copy(Code, ncstart, i - ncstart));
  WriteEndOfCode;
end;

initialization
  ReservedWords := TStringList.Create;

  // construct the list of reserved words.  These will be displayed
  // in bold text.
  ReservedWords.Add('and');
  ReservedWords.Add('array');
  ReservedWords.Add('as');
  ReservedWords.Add('asm');
  ReservedWords.Add('begin');
  ReservedWords.Add('case');
  ReservedWords.Add('class');
  ReservedWords.Add('const');
  ReservedWords.Add('constructor');
  ReservedWords.Add('destructor');
  ReservedWords.Add('dispinterface');
  ReservedWords.Add('div');
  ReservedWords.Add('do');
  ReservedWords.Add('downto');
  ReservedWords.Add('else');
  ReservedWords.Add('end');
  ReservedWords.Add('except');
  ReservedWords.Add('exports');
  ReservedWords.Add('file');
  ReservedWords.Add('finalization');
  ReservedWords.Add('finally');
  ReservedWords.Add('for');
  ReservedWords.Add('function');
  ReservedWords.Add('goto');
  ReservedWords.Add('if');
  ReservedWords.Add('implementation');
  ReservedWords.Add('in');
  ReservedWords.Add('inherited');
  ReservedWords.Add('initialization');
  ReservedWords.Add('inline');
  ReservedWords.Add('interface');
  ReservedWords.Add('is');
  ReservedWords.Add('label');
  ReservedWords.Add('library');
  ReservedWords.Add('mod');
  ReservedWords.Add('nil');
  ReservedWords.Add('not');
  ReservedWords.Add('object');
  ReservedWords.Add('of');
  ReservedWords.Add('or');
  ReservedWords.Add('out');
  ReservedWords.Add('packed');
  ReservedWords.Add('procedure');
  ReservedWords.Add('program');
  ReservedWords.Add('property');
  ReservedWords.Add('raise');
  ReservedWords.Add('record');
  ReservedWords.Add('repeat');
  ReservedWords.Add('resourcestring');
  ReservedWords.Add('set');
  ReservedWords.Add('shl');
  ReservedWords.Add('shr');
  ReservedWords.Add('string');
  ReservedWords.Add('then');
  ReservedWords.Add('threadvar');
  ReservedWords.Add('to');
  ReservedWords.Add('try');
  ReservedWords.Add('type');
  ReservedWords.Add('unit');
  ReservedWords.Add('until');
  ReservedWords.Add('uses');
  ReservedWords.Add('var');
  ReservedWords.Add('while');
  ReservedWords.Add('with');
  ReservedWords.Add('xor');
  ReservedWords.Sorted := True;

finalization
  ReservedWords.Free;

end.
