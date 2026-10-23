class_name PhysicsLayers
extends RefCounted


const WORLD: = 1
const PLAYERS: = 2
const THINGS: = 4
const PROJECTILES: = 8
const DEBRIS: = 16


const SOLID: = WORLD | PLAYERS | THINGS

const DAMAGEABLE: = PLAYERS | THINGS | PROJECTILES
