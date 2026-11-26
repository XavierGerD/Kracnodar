<!--
The Kracnodar grammar, shown (and editable) in the app's Grammaire tab.
  # Title             the page title, once at the top; the line under it is the subtitle
  ## Heading          a chapter        ### Heading   an article within it
  - text              a rule, one per line
  > text              a note
  English → Kracnodar an example line (-> works too)
  | a | b |           a table: the first row is the header; an optional dashed row
  |---|------|        under it sets the relative column widths
  *word*              a Kracnodar word, shown in the Kracnodar style
  ~~word~~            a masked word, struck through
  ![name](path)       an image from the project, as tall as the text is: ![Icon](icon.png)
  ```                 a quote block: the lines between two ``` lines, shown as written
  other text          a paragraph; a blank line starts a new block
The Library uses the same markup, images apart.
-->

# A normative grammar

By Xavier Gervais-Dumont · translated from “Grammaire Kracnodar.docx”

## Introduction

Kracnodar → Kracnodar

- Kracnodar (/ˈkraʃnodar/) is a synthetic, sung language, invented for the Québécois band of the same name.
- Words are built by agglutinating lexemes of two kinds: modules, which carry the meaning (like word roots), and affixes (prefixes or suffixes), which refine the form.
- What ties a word to the rest of the sentence stands apart from it: relation markers (see 2.1.2) and object pronouns (see 2.2) are words of their own.
- An affix never changes the spelling of the module, except where the two share a vowel at the join (see 1.3), in the plural (see 2.1.3), and in the short forms some modules take (see 2.1.1): from one module you can make a noun, a verb, an adjective, an adverb, and so on.
- Some modules can temporarily act as affixes.

## 1.  Building words

### 1.1  The alphabet

- Kracnodar has its own script, written with a quill: a letter for each consonant, and for each vowel both a letter and a diacritic.
- A vowel after a consonant is written as its diacritic, on top of the consonant's letter: *ga* is the letter for *g* with the diacritic for *a* above it.
- A vowel that starts a word is written with its own letter: *atari*.
- A vowel after another vowel, where two lexemes join (see 1.3), is written with its own letter too: *atariex*.
- This grammar spells Kracnodar in Latin letters, one per sound: the Latin alphabet, minus *q*, which duplicates a sound (*k* already covers it).
- *c* is only the voiceless postalveolar fricative /ʃ/ (“sh”); *s* is only the voiceless alveolar fricative /s/.
- *y* is a consonant, never a vowel.
- Vowels: *a*, *e*, *i*, *o*, *u*. The only semivowel: *w*, written as a consonant.
- The Latin spelling has no accents, cedillas or other diacritics.

| Consonant | Consonant | Consonant | Consonant |
|---|---|---|---|
| *b* | *h* | *n* | *v* |
| *c* | *j* | *p* | *w* |
| *d* | *k* | *r* | *x* |
| *f* | *l* | *s* | *y* |
| *g* | *m* | *t* | *z* |

| Vowel | After a consonant |
|---|---|
| *a* | *ba* |
| *e* | *be* |
| *i* | *bi* |
| *o* | *bo* |
| *u* | *bu* |

### 1.2  Pronunciation

- Any pronunciation within the bounds of the International Phonetic Alphabet is acceptable.
- No nasal vowels.
- No liaison between words.

### 1.3  Where words come from and how they are formed

- Words have arbitrary origins; the vocabulary is often built with word generators.
- Modules are rarely longer than two syllables.
- A module or affix on its own has no double consonants, double vowels, diphthongs or vowels in a row.
- This rule doesn't apply where two modules join: *atari* + *ex* → *atariex*.
- When two lexemes join and the first ends with the vowel the second starts with, one of the two vowels can be dropped: *da* + *ava* + *tug* → *daavatug* or *davatug*; *ava* + *ac* → *avac*.
- Where dropping it would spell another word or affix, both vowels stay, joined by a linking consonant: *n* for *e*, *a* and *i*, *v* for *o* and *u*. *e* + *ex* → *enex*, not *ex*.

> Coining new words is strongly encouraged.

## 2.  The parts of the language

### 2.1  Modules

- Roughly the equivalent of word roots; they are the units that carry the most meaning.
- A module with no affix already belongs to a word class: *felek* on its own is a verb, “to free”.
- Modules can join into compounds, where the first module acts as an affix on the second: the modifier comes first, the head last. Only the last module can take the plural (see 2.1.3).

The age of Men → Rukohej
The river of the ages → Hejazo

### 2.1.1  Affixes

- One syllable each, added before or after the module to change its form: most go after it, but some go before it, like *ken* (*Kenfelek*).
- Affixes can be stacked: *mulen* + *op* + *bar* → *mulenopbar*, a place of great fortune.

| Form (affix) | English | Kracnodar | English | Kracnodar |
|------|------|----|------|----|
| Verb (*tan*) | To free | *Felek* | To cool | *Doltan* |
| Noun (*ex*) | Freedom | *Felekex* | (The) cold | *Dolex* |
| Action (*am*) | Liberation | *Felekam* | Cooling | *Dolam* |
| Adverb (*ken*) | Freely | *Kenfelek* | Coldly | *Kendol* |
| Adjective (*pax*) | I am free | *Felekpaxtag* | Cold (I am cold) | *Dol* (*Doltag*, see 2.3) |
| Agent, instrument (*rom*) | Liberator | *Felekrom* | Cooler | *Dolrom* |
| Smaller noun (*fo*) | Small liberation | *Felekfo* | A slight chill | *Dolfo* |
| Bigger noun (*op*) | Great liberation | *Felekop* | A great cold | *Dolop* |
| Place (*bar*) | A place where one is free | *Felekbar* | A place where it is (or one is) cold | *Dolbar* |

- Some modules are shortened before their affixes, dropping their last letters: *geren*, to love, gives *gerex* rather than *gerenex*. Which modules are shortened, before which affixes, and how, is decided word by word, with no rule to predict it: each one is learned with its short forms. *Geren* stays whole in *gerenbar*.
- The full module stays correct before an affix: *gerenex* is love too.

To love → Geren
Love → Gerex
Lovable → Gerpax
To like → Gerfo
To adore → Gerop
A shrine (a place of adoration), not shortened → Gerenbar

> A short form mustn't spell another module or affix: check the dictionary before giving a module one.

### 2.1.2  Relation markers

- They express a relation between the subject and the direct or indirect object.

| Use | Marker | Example |
|-------|---|---------|
| Origin (coming from, of, by)¹ | *Kin* | Dim's apple → *Atari kin Dim* |
| Direction of origin (from where, through where) | *Nik* | Music from the world → *Hotuyavin nik atazu* |
| Direction of destination (to, toward) | *Kan* | I'm going home → *Exotag kan eno* |
| Recipient (to whom, toward whom) | *Nak* | I give you a cat → *Ilitag nak wet zanu* |
| Manner (thus, in this way) | *Ken* | He dances while jumping → *Avac kendexu* |
| Cause (what makes) | *Nek* | The film makes them cry → *Kija nek uc nuto* |
| Relation (of) | *Ti* | The presence of things → *Urivo ti oju* |
| Relative, possessive (whose, of which) | *Osa* | The dwarf whose hammer rings → *Wanon osa zek relinno* |
| Relative (who, which) | *Gol* | A person who stinks → *Onupo gol awu* |
| Time (at the time of, at) | *Kosa* | We dance at the time of the liberation → *Avatug kosa felekam* |
| Relation (as for) | *Vof* | As for me → *Vof tag* |
| Because | *Iduri* | I cry because you go → *Nutotag iduri exowet* |

> ¹ Possession can also be expressed with pronouns (see 2.2).

- A marker is a word of its own, placed before its noun like a preposition (see 2.5): *ti nod*, *kin Dim*.
- *Ken* on a bare module is the adverb affix instead, joined to it (see 2.1.1): *kendexu*, while jumping. Before a noun, it is a marker like the others: like jewels → *ken uzonodu*.
- A marker also covers the nouns joined to its noun by *g*, which joins the noun right before it: the marker isn't repeated.

The houses of stone and gold → Enu ti nod g lox
The age of the sun and the moon → Hej ti iwa g umi

### 2.1.3  Plural

- A noun is made plural with *u*, after any other affix: the plural always ends the word.
- After a final consonant, *u* is added: *nod* → *nodu*; *felekrom* → *felekromu*.
- A final vowel is replaced by *u*: *atari* → *ataru*; *eno* → *enu*; *kija* → *kiju*.
- A final *u* is replaced by *e*: *ru* → *re*; *zanu* → *zane*.
- Apart from the short forms of some modules (see 2.1.1), this is the only affix that changes the spelling of what it attaches to, an affix included: *felekfo* → *felekfu*, small liberations.
- A noun takes the plural wherever it is plural, even when the verb already says so: words open the way → *re kadirnu joka*.
- Pronouns have plurals of their own (see 2.2), and adjectives don't agree with the noun.
- In the script, the plural is the diacritic on the last letter: added after a consonant (*nodu*), changed where it replaces a vowel (*ataru*).

| Noun ends with | Plural | Singular | Plural |
|------|------|----|----|
| A consonant | *u* added | *Nod* | *Nodu* |
| *a*, *e*, *i*, *o* | Replaced by *u* | *Atari* | *Ataru* |
| *u* | Replaced by *e* | *Ru* | *Re* |

Stones → Nodu
The houses of stone → Enu ti nod
Our apples → Tugataru
Small liberations → Felekfu

> The singular can't always be told from the plural: *ataru* could come from *atar*, *atara*, *atare*, *atari* or *ataro*. When coining a noun, avoid one that differs from another only by its last vowel, or ends like the plural of another: *kijo* beside *kija* would share its plural, *kiju*.

### 2.2  Pronouns

- Pronouns don't take affixes, but they join onto other modules in some conjugations.
- The subject pronoun attaches to the end of the verb: *Exotag*, I go; *Gewigac*, he eats.
- *Noc* (all) attaches to the verb like the others. After a noun subject, it takes the place of *uc* or *nu* and says that all of them do it: *lorevu evohenoc*, the Gods all agree. In front of a noun it would mean possession, so “all the Gods” is never *noclorevu*.

| English | Kracnodar |
|---|---|
| I | *Tag* |
| You (singular) | *Wet* |
| He / She (a person) | *Ac* |
| It (a thing) | *No* |
| We | *Tug* |
| You (plural) | *Wut* |
| They (people) | *Uc* |
| They (things) | *Nu* |
| One | *Tul* |
| All | *Noc* |

- A plural pronoun is the singular with its vowel replaced by *u*, the vowel of the plural (see 2.1.3): *tag* → *tug*, *wet* → *wut*, *ac* → *uc*, *no* → *nu*. Like the singular, it is one syllable wherever it stands: *gewiguc*, they eat; *ucatari*, their apple.
- *Ac* and *uc* are said of persons, *no* and *nu* of things, so a person and the thing they handle never share a pronoun: he takes it → *no atoac*; it rings → *relinno*.
- There is no polite form: *wet* is anyone spoken to, a friend or a god, and *wut* any number of them.
- A pronoun that is the direct object is a word of its own, right before the verb, as French puts “le” before the verb; it is sung onto the verb without a break: he puts it → *no vegoac*; they free us → *tug felekuc*. The subject stays at the end of the verb, so where the pronoun stands tells them apart: *ac felekuc*, they free him; *uc felekac*, he frees them. A verb whose object is its own subject takes *tu* instead (see 2.3): *tu vegoac*, he puts himself.
- The object also comes before a tense prefix, which stays on the verb: he is about to put it → *no davegoac*. A pronoun that receives keeps *nak*: *ilitag nak wet zanu*.
- Possession is expressed with the pronoun in front of the noun, joined to it, wherever the noun stands in the sentence: *tugatari*, our apple; *tageti*, my mother.
- So a pronoun joined to the front of a word is always a possessor, and a pronoun standing alone before a verb is always its object: *uclevoam*, their shaping; *uc levo*, to shape them.
- For emphasis, the pronoun goes after the noun with *kin* instead, like “of mine”: *eti kin tag*, mother of mine. A possessor that isn't a pronoun always takes *kin*: *atari kin Dim*.
- A body part that belongs to the subject takes no possessor, as in French “il ferme les yeux”: he closes his fingers → *leac nesu*; he puts it in his palm → *no vegoac ga fih*. A body part that belongs to someone else keeps it: in his palm, it reddens → *ga acfih vireno*. Only body parts drop it: he puts his ingots in the crucible → *vegoac achosu ga vembar*.

We eat an apple → Gewigtug atari
We eat our apple → Gewigtug tugatari
We feed the prisoners → Fedamotug adovisu
We feed our prisoners → Fedamotug tugadovisu
My mother, the fire → Tageti, vul
Mother of mine → Eti kin tag
The Gods all agree → Lorevu evohenoc
Etovo puts it on the fire → Etovo no vegoac gu vul
He puts his ingots in the crucible → Vegoac achosu ga vembar

- After a noun, a pronoun joined to *tu* (“one”) stresses it, as “itself” does, and agrees with the noun: *tagtu*, *wettu*, *actu*, *notu*, *tugtu*, *wuttu*, *uctu*, *nutu*. Before a verb, *tu* alone is reflexive instead (see 2.3).
- *Tu* never takes the plural, which would make it *te*, the distant past (see 2.3): the pronoun in front of it gives the number.

Life itself → Idex notu
The words themselves → Re nutu
Kulena herself → Kulena actu

### 2.3  Verbs

- Verbs conjugate only for tense, which is marked by a prefix.

| Distant past | Recent past | Present | Near future | Distant future |
|---|---|---|---|---|
| *te* | *mi* | *sele* | *da* | *fo* |

- The present marker (*sele*) is usually left out, except to stress that something is happening right now.
- The conditional is marked by *s*: we could → *siredotug*.
- A reflexive verb takes *tu* (“one”) as its object, a word of its own placed like an object pronoun (see 2.2): I isolate myself → *tu ojisitag*; he puts himself → *tu vegoac*. *Tu* is the same for every person, since the subject ending already says who. Before a verb, *tu* always means “self”; before a noun, it is the number one (see 2.9).
- A reciprocal verb takes *tul* as its object, placed the same way: they anger one another → *tul nasovetanuc*; we love one another → *tul gerentug*, beside *tu gerentug*, we love ourselves. Before a verb, *tul* always means “one another”: as the subject, “one”, it ends the verb like any other subject.
- The imperative is the same as the infinitive, with no pronoun: eat an apple → *gewig atari*.
- A noun or an adjective takes *tan* to become a verb (see 2.1.1), but *tan* is only required in the infinitive and the imperative. A conjugated verb ends with its subject, and that ending alone makes it a verb, so *tan* can be dropped: he speaks → *ruac* (or *rutanac*); they speak → *ruc* (*ru* + *uc*, see 1.3); we war → *mortug*; he closes his fingers → *leac nesu* (or *letanac nesu*, see 2.2). The verb means what it would with *tan*: *ru*, word, gives “to speak”.
- The infinitive and the imperative have no subject ending, so they keep *tan*: to speak, speak → *rutan*; behold → *hitan*. So does a verb after *ipe*, which takes the infinitive (to hold → *ipe tortan*), and after *gol*.
- On an adjective, *tan* means “to make” or “to become”: I cool it → *no doltantag*; they anger one another → *tul nasovetanuc*. With *tan* dropped, the ending alone can mean the same, and it can also mean “to be”: I am cold → *doltag*; they are rough → *jehouc*. An object shows that it means “to make”: I cool it → *no doltag*. Where “to become” must be told from “to be”, keep *tan*. *Pax* is only needed on a module that isn't an adjective: I am free → *felekpaxtag*.

> Keeping *tan* is never wrong: it gives a syllable back where the melody needs one.

- Word order is subject, verb, object. A noun subject goes before the verb, and the verb keeps its pronoun: Dim eats an apple → *Dim gewigac atari*.
- An adverb goes right after the verb: hear now → *jas zipo*.

### 2.4  Intensity markers

- A word's intensity is adjusted with an affix: *fo* to lessen it, *op* to increase it.

### 2.5  Prepositions

| English | Kracnodar |
|---|---|
| In | *ga* |
| On | *gu* |
| But | *tirel* |
| And, between clauses | *o* |
| With | *ka* |
| For | *ipe* |

- *Ipe* followed by an infinitive expresses a purpose: I'm going home to eat → *exotag kan eno ipe gewig*.
- “And” is *g* between words, and *o* between two clauses: I go home and I eat → *exotag kan eno, o gewigtag*.

### 2.6  Determiners

| English | Kracnodar |
|---|---|
| This / That | *k* |

- *K* is a separate word, placed before the noun: that stone → *k nod*.
- A relation marker comes before *k*: in that age → *kosa k hej*.

### 2.7  Question words

- A question word takes the place in the sentence that the answer would take.
- Since subject and direct object are told apart only by their position, *hob* and *her* can't be moved without creating ambiguity.
- *Hura*, *hen*, *reh* and *hid*, whose function is clear from the word itself, can go anywhere, including at the start of the sentence.
- Outside a question, “where” is *nev hura*: where his hammer sounds → *nev hura, aczek relinno*.

Who eats an apple? → Hob gewigac atari ?
What does Dim eat? → Dim gewigac her ?
Where does Dim eat? → *Dim gewigac hura ?* or *Hura Dim gewigac ?*
Why does Dim eat? → *Dim gewigac hid ?* or *Hid Dim gewigac ?*

| English | Kracnodar |
|---|---|
| Where | *Hura* |
| When | *Hen* |
| How | *Reh* |
| Why | *Hid* |
| What | *Her* |
| Who | *Hob* |

### 2.8  Negation

- Negation is expressed with *fem*, placed right after the word it negates; its position alone sets its scope.
- On its own, *fem* means “no”.
- *Femop* (*fem* + *op*, “not more”) means “no more, no longer”, and is placed like *fem*. It is a word of its own, not a stronger *fem*.
- In a question, it comes before the marker *ot*.
- Attached to a question word, it forms the negative words, which are placed like question words.
- One negation per clause is enough.

He doesn't eat an apple → Gewigac fem atari
Doesn't he eat an apple? → Gewigac fem ot atari ?
He eats nothing → Gewigac femher
He no longer eats apples → Gewigac femop ataru
We war no more → Mortug femop
I can't free → Iredotag fem felek
I can not free (I'm able not to) → Iredotag felek fem

| English | Kracnodar |
|---|---|
| No more, no longer | *Femop* |
| Nowhere | *Femhura* |
| Never | *Femhen* |
| In no way | *Femreh* |
| For no reason | *Femhid* |
| Nothing | *Femher* |
| Nobody | *Femhob* |

### 2.9  Numbers

- A number is a separate word placed before the noun, like *k*. The noun still takes the plural: three stones → *va nodu*; one stone → *tu nod*.

| Number | Kracnodar | Number | Kracnodar |
|---|---|---|---|
| 0 | *ra* | 6 | *do* |
| 1 | *tu* | 7 | *sa* |
| 2 | *go* | 8 | *ko* |
| 3 | *va* | 9 | *su* |
| 4 | *ju* | 10 | *de* |
| 5 | *he* | | |

- From eleven to nineteen: *de*, then *o* (“and”), then the digit: twelve → *deogo*.
- The tens: *de*, then how many tens, with no *o*: twenty → *dego*; thirty → *deva*.
- Between two tens: the digit, then *o*, then the tens: thirty-five → *heodeva*.
- After *go*, *do* and *ko*, the two *o* always merge into one: thirty-two → *godeva*, not *goodeva*.
- In a number, *o* always adds: *deogo* is ten and two, *dego* is two tens.
- A *t* at the end of a number makes it an ordinal, placed like the number: first → *tut*; ninth → *sut*; thirty-fifth → *heodevat*.
- *Tuop* (*tu* + *op*, see 2.4) is “a single one”, placed like a number, before a singular noun: a single stone → *tuop nod*.
- *Tufo* (*tu* + *fo*, “less than one”) is a piece, a part of a whole. It is a noun, plural *tufu*: she breaks it into seven pieces → *berac sa tufu*.

Eleven → Deotu
Twelve → Deogo
Twenty → Dego
Twenty-one → Tuodego
Thirty-two → Godeva
Thirty-five → Heodeva
Ninety-nine → Suodesu
Three stones → Va nodu
The first day → Tut voni
The twelfth stone → Deogot nod
A single day → Tuop voni
Seven pieces → Sa tufu

> Numbers stop at ninety-nine for now: the hundreds aren't settled yet.
