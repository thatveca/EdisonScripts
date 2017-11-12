script "Bitcrusher" language "pascal";

// Calculate x^y
function Pow(x, y: Double): Double;
begin
   Pow := Exp(y * Ln(x));
end;

// Main bitcrushing procedure
procedure Bitcrusher(freq, mix, cutoff, res : Single; bits : Integer; normalize : Boolean);
var n, c, x1, x2 : Integer;
    s, x, y, step, phasor, last : Single;
    TempSample : TSample;
    fs : Integer;
    t, t2, scale, f, k, p, e, r, y1, y2, y3, y4, oldx, oldy1, oldy2, oldy3 : Single;
    input : Single;
begin

if (EditorSample.Length <= 0) then exit;

fs := EditorSample.Samplerate;

// Create temporary sample
TempSample := TSample.Create;
TempSample.Length := EditorSample.Length;
TempSample.SampleRate := EditorSample.SampleRate;
TempSample.NumChans := EditorSample.NumChans;

Editor.GetSelectionS(x1, x2); // Set bounds

// If nothing is selected, select everything
if (x1 = x2) then
begin
    x1 := 0;
    x2 := EditorSample.Length;
end;

// Filter setup
f := (cutoff + cutoff) / fs;
p := f * (1.8 - 0.8 * f);
k := p + p - 1.0;
t := (1.0 - p) * 1.386249;
t2 := 12.0 + t * t;
r := res * (t2 + 6.0 * t) / (t2 - 6.0 * t);
y1 := 0;
y2 := 0;
y3 := 0;
y4 := 0;
oldx := 0;
oldy1 := 0;
oldy2 := 0;
oldy3 := 0;     
        
// Bitcrusher setup
step := 1. / Pow(2., Double(bits));
phasor := 0;
last := 0;

// Bitcrushing
for n := x1 to x2 do 
begin
    // Progress message
    if ((n - x1) mod 10000) = 0 then ProgressMsg('Bitcrushing...', n - x1, x2 - x1);

    for c := 0 to (EditorSample.NumChans - 1) do
    begin
        x := EditorSample.GetSampleAt(n, c);

        phasor := phasor + (freq / EditorSample.SampleRate);
        if (phasor >= 1.0) then
        begin
            phasor := phasor - 1.0;
            last := step * Round(x / step + 0.5); // Quantize
        end;

        s := last; // Sample and hold

        TempSample.SetSampleAt(n, c, s);
    end; // c
end; // n

// Wet/dry mix
for n := x1 to x2 do 
begin
    for c := 0 to (EditorSample.NumChans - 1) do
    begin
        x := EditorSample.GetSampleAt(n, c);
        y := TempSample.GetSampleAt(n, c);
        s := (1 - mix) * x + mix * y; 
        EditorSample.SetSampleAt(n, c, s);
    end; // c
end; // n

// Filtering (4-pole lowpass)
for n := x1 to x2 do 
begin
    // Progress message
    if ((n - x1) mod 10000) = 0 then ProgressMsg('Filtering...', n - x1, x2 - x1);
    for c := 0 to (EditorSample.NumChans - 1) do
    begin
        input := EditorSample.GetSampleAt(n,c);
        x := input - r * y4;
        y1 := x * p + oldx * p - k * y1;
        y2 := y1 * p + oldy1 * p - k * y2;
        y3 := y2 * p + oldy2 * p - k * y3;
        y4 := y3 * p + oldy3 * p - k * y4;
        y4 := y4 - ((y4 * y4 * y4) / 6.0);
        oldx := x;
        oldy1 := y1;
        oldy2 := y2;
        oldy3 := y3;
        EditorSample.SetSampleAt(n, c, y4);
    end; // c
end; // n

// Normalize again?
if (normalize) then EditorSample.NormalizeFromTo(x1, x2, 1.0);

TempSample.Free;

end; // end function Bitcrusher

// --------------------------------------------------------------------------

var Form : TScriptDialog;

// Constants ----------------------------------------------------------------
const freqLbl = 'Sample rate (Hz)';
const freqMin = 250;
const freqMax = 44100;
const freqDefault = 8000;

const bitsLbl = 'Bits';
const bitsMin = 1;
const bitsMax = 24;
const bitsDefault = 24;

const mixLbl = 'Dry/wet mix';
const mixMin = 0;
const mixMax = 1;
const mixDefault = 0.8;

const normLbl = 'Normalize?';
const normChoices = 'No,Yes';
const normDefault = 0; // Yes

const cutoffLbl = 'Cutoff';
const cutoffMin = 1;
const cutoffMax = 22100;
const cutoffDefault = 500;

const resoLbl = 'Resonance';
const resoMin = 0;
const resoMax = 1;
const resoDefault = 0;

// end Constants ------------------------------------------------------------

// --------------------------------------------------------------------------
begin

Form := CreateScriptDialog('Bitcrusher',
                           'Bit reduction, and sample-and-hold at the specified rate.' + CRLF + 
                           'Includes a 24 dB/oct lowpass filter.');

Form.AddInputKnob(freqLbl, freqDefault, freqMin, freqMax);
Form.AddInputKnob(bitsLbl, bitsDefault, bitsMin, bitsMax);
Form.AddInputKnob(mixLbl, mixDefault, mixMin, mixMax);
Form.AddInputCombo(normLbl, normChoices, normDefault);
Form.AddInputKnob(cutoffLbl, Round(EditorSample.Samplerate / 2), cutoffMin, Round(EditorSample.Samplerate / 2));
Form.AddInputKnob(resoLbl, resoDefault, resoMin, resoMax);

if Form.Execute then 
begin
    Bitcrusher(Form.GetInputValue(freqLbl), Form.GetInputValue(mixLbl),
               Form.GetInputValue(cutoffLbl), Form.GetInputValue(resoLbl),
               Form.GetInputValueAsInt(bitsLbl), (Form.GetInputValueAsInt(normLbl) = 1));
end;

Form.Free;
end.
