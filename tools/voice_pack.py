"""Builds the game's voice pack from docs/voice_script.csv.

    python tools/voice_pack.py link
        Looks for each file in the script under assets/voice/ and writes
        assets/voice/clips.json for the ones that exist. Run it after copying
        in recordings. Entries you added to clips.json by hand are kept.

    python tools/voice_pack.py google
        Makes every missing clip with Google Cloud Text-to-Speech, then runs
        "link". Needs an API key with the Text-to-Speech API turned on:
            set GOOGLE_TTS_KEY=your-key        (Windows)
            export GOOGLE_TTS_KEY=your-key     (Mac/Linux)
        Change the voices in VOICES below. Only the standard library is used.

See docs/VOICES.md.
"""
import base64
import csv
import json
import os
import sys
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SCRIPT = os.path.join(ROOT, 'docs', 'voice_script.csv')
VOICE_DIR = os.path.join(ROOT, 'assets', 'voice')
CLIPS = os.path.join(VOICE_DIR, 'clips.json')

# Google voice for each voice group (trainers share the boy or girl set). List them with:
#   https://cloud.google.com/text-to-speech/docs/voices  (Bengali, bn-IN)
VOICES = {
    'boy': {'name': 'bn-IN-Wavenet-B', 'pitch': 4.0, 'rate': 1.0},
    'girl': {'name': 'bn-IN-Wavenet-A', 'pitch': 4.0, 'rate': 1.0},
}


def rows():
    with open(SCRIPT, encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def link():
    try:
        with open(CLIPS, encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        data = {}
    clips = data.get('clips', {})
    scripted = {f"{r['speaker']}|{r['text']}" for r in rows()}
    # Keep hand-made entries; rebuild the scripted ones from what exists.
    clips = {k: v for k, v in clips.items() if k not in scripted}
    found = 0
    for r in rows():
        if os.path.exists(os.path.join(VOICE_DIR, r['file'])):
            clips[f"{r['speaker']}|{r['text']}"] = r['file']
            found += 1
    data.setdefault('_help', 'Recorded voice clips. See docs/VOICES.md.')
    data['clips'] = clips
    with open(CLIPS, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'clips.json: {found} of {len(rows())} scripted clips found, {len(clips)} entries in all.')


def google():
    key = os.environ.get('GOOGLE_TTS_KEY')
    if not key:
        sys.exit('Set GOOGLE_TTS_KEY first (see the top of this file).')
    url = f'https://texttospeech.googleapis.com/v1/text:synthesize?key={key}'
    todo = [r for r in rows() if not os.path.exists(os.path.join(VOICE_DIR, r['file']))]
    print(f'{len(todo)} clips to make.')
    for i, r in enumerate(todo, 1):
        v = VOICES.get(r['speaker'], VOICES['girl'])
        body = {
            'input': {'text': r['text']},
            'voice': {'languageCode': 'bn-IN', 'name': v['name']},
            'audioConfig': {
                'audioEncoding': 'MP3',
                'pitch': v['pitch'],
                'speakingRate': v['rate'],
                'sampleRateHertz': 24000,
            },
        }
        req = urllib.request.Request(
            url, json.dumps(body).encode(), {'Content-Type': 'application/json'})
        with urllib.request.urlopen(req) as res:
            audio = base64.b64decode(json.load(res)['audioContent'])
        path = os.path.join(VOICE_DIR, r['file'])
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as f:
            f.write(audio)
        print(f"[{i}/{len(todo)}] {r['file']}  {r['text']}")
    link()


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    if cmd == 'link':
        link()
    elif cmd == 'google':
        google()
    else:
        print(__doc__)
