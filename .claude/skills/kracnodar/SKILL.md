---
name: kracnodar
description: Work in the Kracnodar repo, the sung constructed language and its Godot app. Use for any task here, and above all for translating between English and Kracnodar, changing or adding a word, or editing grammar.md, dict.json or library.md.
---

# Working in Kracnodar

## Before anything else

1. Read `grammar.md` in full. It is the authority on how words are built (modules, affixes, compounds, short forms, vowel joins, plural) and how sentences are ordered.
2. Read `dict.json` in full. Each entry is keyed by its French name and holds `en`, `kr`, `class` (French class names: `nom`, `verbe`, `adjectif`, `affixe`…) and sometimes `derived`, the forms already settled for it.

Do both every time, even for a small task: the user edits these files between sessions, so what you remember of them may be stale.

## Translating English into Kracnodar

### One line at a time

Unless the user says otherwise, translate one line, meaning one `English → Kracnodar` pair, then stop. Show it in the format below, and wait for the user to approve or correct it before moving to the next line. Corrections often change words or rules that later lines will use.

### How to show a translation

Show each line like this:

1. The original English line, as given.
2. The English line with your changes (see "Favor the Kracnodar"). If you changed nothing, write "(unchanged)".
3. The Kracnodar line.
4. A table that breaks the Kracnodar line into its logical units (a word, a compound, a marker with its noun where that reads best), in sentence order, with three columns: Kracnodar, English, Explanation. The explanation says how the unit is built and which grammar rule applies. It marks any word you built that isn't in dict.json as **new**, and any gap as `[?english word]`.

For example:

> **Original:** Within his forge
> **English:** In his forge
> **Kracnodar:** Ga lokbar kin ac
>
> | Kracnodar | English | Explanation |
> |---|---|---|
> | *ga* | in | Preposition (2.5) |
> | *lokbar* | forge | **New:** *lok*, to forge + *bar*, place (2.1.1) |
> | *kin ac* | his | *kin*, of + *ac*, he; *kin* gives emphasis after the noun (2.2) |

After the table, list any gaps for the user to fill and say briefly why you changed the English.

### Writing it into the Library

When the line comes from `library.md` or belongs there, you may update `library.md` directly, without asking first. Write the line as `English → Kracnodar`, using the adjusted English, in place of the original line. Keep any numbering (`1. … → 1. …`) and the markup. Re-read the file right before each edit, since the user may be editing it in the app. When the user corrects a line, apply the correction there too.

### Build words, don't make up sounds

- Before calling a word missing, look for it under a synonym, a nearby meaning, or the French key, and check whether it can be derived from a word already there.
- If it isn't there, build it from what exists, following the grammar: a module plus affixes (`ex` noun, `am` action, `rom` agent or instrument, `bar` place, `fo` smaller, `op` bigger, `ken` adverb, `pax` adjective, `tan` verb), compounds (the modifier first, the head last), `fem` for negation, numbers and pronouns. Build new words like this wherever you can, rather than shying away from them. For example: *rukohej*, the age of Men; *lokbar*, a forge; *rocfem*, endless.
- Check each word you build against the grammar's rules. It mustn't spell an existing module or affix. A dropped vowel at a join mustn't create another word (1.3). Its plural mustn't collide with another noun's plural (2.1.3). A short form must be one dict.json already gives that module.
- **If no word can be built from existing modules, don't invent a new module or sound.** That choice belongs to the user. Translate the rest of the line, mark the gap as `[?english word]`, and list every gap at the end of your reply so the user can supply the sounds.

### Favor the Kracnodar

- The Kracnodar sentence comes first. Use the language's own idiom (its word order, compounds, relation markers, dropped `tan`, body parts without a possessor) instead of copying English structure word for word.
- You may rework the English a little so it matches the Kracnodar sense. For example, reword a phrase to mirror a compound, or drop a nuance the Kracnodar doesn't carry. Keep its meaning, tone and register, which in the Library is archaic and solemn.
- Say briefly where you changed the English and why.

### New words stay out of dict.json

Words you built are marked **new** in the breakdown table. Don't add them to dict.json unless the user asks.

## Changing a word or a rule

When the user changes a word's sound or a grammar rule, update every place it appears:

- `dict.json`: the entry itself, plus any `derived` forms built on it.
- `grammar.md`: the rules, tables and example lines (`English → Kracnodar`, and *italic* Kracnodar words).
- `library.md`: every Kracnodar line that uses it, including compounds and conjugated or plural forms, not only the bare word.

Search for whole words only. For example, *g* "and" is not the *g* in *ga* "in" or in the alphabet table. Check each match against its English side before changing it. If dict.json and the user's message disagree on a spelling, ask which one is right; in Kracnodar *c* is /ʃ/, so *hoc* and *hok* are different words. Leave the exported `Kracnodar.pck` alone, since it updates on the next export.

## The files

- `grammar.md` and `library.md` are shown and edited in the app (the Grammaire and Bibliothèque tabs). The markup is explained in the comment at the top of each file. Follow it, and keep `English → Kracnodar` as one line per sentence pair.
- The user also edits these files in the app, so re-read a file right before you change it, and never overwrite their unsaved work.
- `Scripts/` holds the Godot (GDScript) app. `Docs/` holds the original .docx sources. Don't edit those.
