"""Plural voice commands address every owned, visible creature of that species."""
from add_dinosaur_pack import read, write
import re
import unicodedata

def fold(text):
    text = ''.join(c for c in unicodedata.normalize('NFD', text.lower()) if unicodedata.category(c) != 'Mn')
    return ' '.join(re.sub('[^a-z0-9]+', ' ', text).split())

ORDERS = {
    'follow': ['me sigam', 'sigam me', 'sigam o jogador', 'venham comigo', 'venham aqui'],
    'stay': ['fiquem aqui', 'fiquem parados', 'parem aqui', 'parem'],
    'guard': ['protejam minha casa', 'protejam a casa', 'defendam minha casa'],
    'attack': ['ataquem aquele jogador', 'ataquem o jogador', 'ataquem aquele inimigo', 'ataquem', 'ataquem ele', 'ataquem aquele animal', 'ataquem aquela criatura'],
    'evade': ['fujam das bombas', 'evitem as bombas'],
    'retaliate': ['ataquem só quem me atacar', 'ataquem apenas quem me atacar'],
    'free': ['voltem ao normal', 'ajam normalmente', 'cancelem a ordem'],
    'aggressive': ['sejam agressivos', 'sejam agressivas', 'ataquem tudo na sua frente', 'fiquem agressivos'],
}

def main():
    definitions = read('defs/things.json')
    animals = read('lexicon/pt_br/things.json')
    commands = read('defs/commands.json')
    phrases = read('lexicon/pt_br/commands.json')
    attack_words = ['ataque', 'ataca', 'ataque ele', 'ataque aquele animal', 'ataque aquela criatura']
    occupied = {fold(word) for key, value in phrases.items() if key.startswith('pokemon_') for word in value['words']}
    for key, settings in commands.items():
        if not key.startswith('animal_order_') or settings.get('animal_order') != 'attack': continue
        nouns = animals.get(settings.get('species', ''), {}).get('words', [])
        additions = [noun + ' ' + verb for noun in nouns for verb in attack_words] if nouns else attack_words
        phrases[key]['words'] = list(dict.fromkeys([*phrases[key]['words'], *[word for word in additions if fold(word) not in occupied]]))
    for key in list(commands):
        if key.startswith('animal_group_'):
            del commands[key]
            phrases.pop(key, None)
    for species in ['', *[k for k, v in definitions.items() if isinstance(v, dict) and v.get('category') == 'creature']]:
        word_data = animals.get(species, {})
        singulars = word_data.get('words', [])
        plurals = word_data.get('forms', []) or [w if w.endswith('s') else w + 's' for w in singulars]
        if species == 'dog': plurals = [*plurals, 'cachoros', 'caxorros']
        for action, verbs in ORDERS.items():
            key = 'animal_group_' + (species + '_' if species else '') + action
            commands[key] = dict(animal_order=action, species=species, all=True)
            forms = []
            if not species:
                forms = [prefix + verb for prefix in ['todos ', 'todas ', 'todos os animais ', 'todas as criaturas '] for verb in verbs]
            else:
                # Plural nouns also accept singular verb transcription ("cachorros me siga").
                old = phrases.get('animal_order_' + action, {}).get('words', [])
                forms += [noun + ' ' + verb for noun in plurals for verb in [*verbs, *old]]
                forms += [noun + ' ' + verb for noun in singulars for verb in verbs]
                forms += [prefix + noun + ' ' + verb for prefix in ['todos os ', 'todas as '] for noun in [*singulars, *plurals] for verb in verbs]
                # Invariant nouns such as "louva-deus" still need singular orders.
                primary = [singulars[0] + ' ' + verb for verb in old]
                reserved = {fold(word) for word in primary}
                forms = [word for word in forms if fold(word) not in reserved]
                single_key = 'animal_order_' + species + '_' + action
                phrases[single_key]['words'] = list(dict.fromkeys([*phrases[single_key]['words'], *primary]))
            unique = {fold(form): form for form in reversed(forms)}
            phrases[key] = dict(words=list(reversed(list(unique.values()))))
    # Some pre-existing dinosaur aliases already contain plural nouns. Give their
    # plural commands to the group handler instead of creating ambiguous phrases.
    group_words = {fold(word) for key, value in phrases.items() if key.startswith('animal_group_') for word in value['words']}
    for key, value in phrases.items():
        if key.startswith('animal_order_'):
            value['words'] = [word for word in value['words'] if fold(word) not in group_words and fold(word) not in occupied]
    write('defs/commands.json', commands)
    write('lexicon/pt_br/commands.json', phrases)

if __name__ == '__main__': main()
