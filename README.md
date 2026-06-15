# Paso

A small 2D puzzle game where you solve each level by writing tiny programs, and a robot runs them in front of you.

## What it is

In Paso the puzzles *are* programs. Each level gives you a goal in plain language (take these three numbers and hand them back reversed, drop the zeros, that sort of thing) and a small set of instructions to pull it off. You stack the instructions, press run, and watch the robot do exactly what you told it: grab a value, stash it in memory, hand it out. Get the right output and you've solved it. Then the actual challenge kicks in, which is solving it in fewer instructions and fewer steps.

I started it because of something I keep running into as a teaching assistant. Programming is hard to get into, and most of how we teach it is pretty dry. On top of that, people usually learn on a loose, forgiving language and then struggle later when they meet a strict, typed one. I wanted a game that makes the logic underneath actually click, and that you'd want to keep playing for its own sake.

## How it plays

The goal reads like a sentence, not like a spec. You only get the instructions a level needs, and the set grows as things get harder. The robot runs your program step by step and shows everything: what it's holding, what's in memory, what's coming out. Every solution gets scored on instructions used and steps run, and beating your own best score is where most of the fun lives.

The instructions read in plain Spanish (`agarrá`, `guardá`, `soltá`, and so on), but the values have types and memory is declared the way it would be in a real language. I want to push that further and eventually show your finished solution as actual C# code, so the game leans toward typed programming instead of hiding it.

## Status

Early but playable. There are 12 hand-built levels that walk through sequencing, memory, arithmetic, loops and conditionals, roughly in that order. The full loop is there: build a program, run it, check it, then try to make it smaller. The first couple of levels have a guided tutorial.

Next up: the "show it in C#" view, more levels, real sound, and a daily puzzle somewhere down the line.

## How I'm building it

I handle the design, the difficulty curve and the architecture, and I use Claude Code to write a lot of the implementation, backed by a strict test setup so nothing drifts. It's partly an experiment in building something real this way, and so far it's let me move quickly without losing the thread on the design.

One decision that's paid off: the simulation is kept fully separate from the rendering. A small pure interpreter takes state in and gives state out, the tests hit that directly, and the interface only ever draws a snapshot of it. Levels are just data files, so adding one never means touching code.

## Built with

Godot 4 and GDScript, no external dependencies.

## Run it

Clone it, open the folder in Godot 4, and hit play.

```
git clone https://github.com/AngeloVPerrotta/Paso.git
```

## About

I'm Angelo, a systems engineering student in Buenos Aires, building things at the crossroads of programming and education. Paso is the project I'm enjoying the most right now. It's a work in progress, so if you give it a try I'd like to hear what you think.
