import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { draftSnapshot, submittedSnapshot } from '../lib/form-state.mjs';

const catalog = JSON.parse(await fs.readFile(new URL('../lib/catalog.json', import.meta.url), 'utf8'));
const sent = submittedSnapshot('Agence Settat', [{ id: 's1-r10', quantity: 3, comment: 'Remplacement' }], catalog.items);
const original = { 's1-r10': { quantity: '3', comment: 'Remplacement' } };
assert.equal(draftSnapshot('Agence Settat', original, catalog.items), sent);
assert.equal(draftSnapshot(' Agence   Settat ', { 's1-r10': { quantity: '3.00', comment: ' Remplacement ' }, 's2-r172': { quantity: '', comment: '' } }, catalog.items), sent, 'Formatting and unused rows do not create a new unsent version');
const edited = { ...original, 's2-r172': { quantity: '2', comment: 'Dernier article de la deuxième feuille' } };
assert.notEqual(draftSnapshot('Agence Settat', edited, catalog.items), sent, 'Changes in the second sheet need a new send');
assert.notEqual(draftSnapshot('Agence Settat', { 's1-r10': { quantity: '', comment: '' } }, catalog.items), sent, 'Deleting a previous need is an unsent change');
assert.notEqual(draftSnapshot('Agence Settat', { 's1-r10': { quantity: '', comment: 'À compléter' } }, catalog.items), sent, 'Incomplete needs still need a warning');
assert.equal(draftSnapshot('Agence Settat', JSON.parse(JSON.stringify(original)), catalog.items), sent, 'Reloading a sent draft does not re-enable the warning');
assert.equal(draftSnapshot('Agence Settat', { 's1-r10': { quantity: '3', comment: 'Remplacement' } }, catalog.items), sent, 'Reverting edits removes the warning');
assert.notEqual(draftSnapshot('Agence Casablanca', original, catalog.items), sent, 'Changing agency needs a new send');
console.log('PASS: suivi des versions envoyées, modifications des deux feuilles, suppressions, brouillons incomplets et restauration après rechargement.');
