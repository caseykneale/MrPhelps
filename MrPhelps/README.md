# Mr Phelps
So the main idea for this work in progress is a distributed/local task scheduling
system that makes life easy. The approach is somewhat unique from a lot of other schedulers, as you might presume it is experimental. Rather then "compile" ahead of time calculations, or spam one to all connections the idea here is a dynamic graph. Workers are allocated based on a mincost flow resource constrained problem. Basically fancy talk for "track resources, and distribute tasks accordingly", and even fancier talk for using the LightGraphs package ecosystem. Of course there are some neat bits planned to be included, like a boiler plate Web-UI. In reality this was just an exercise in using what was already available in the Julia ecosystem.

### Goals
The first goal is to lock down embarrassingly parallel tasks, which in and of
itself is not very useful. But, it's a good way to define the problem and make a
minimum viable example.

### Future Plans
Will it make it to 1.0 status? That's for the community to decide. This was a learning experience for me personally. I invited many others to contribute selfishly so I could learn from them, but none have so far. My interests, are satisfied as soon as the minimal thing is working. If anyone wants to carry to torch, or help out, afterward I will be around to support! But my skillset is likely better suited to improving other areas in the ecosystem.


### Current Design

1. messingaroundstructs.jl - contains some really crude examples of how the package may be used. The prescribed workflow is as follows:
- Connect machines to local host via Distributed.jl as usual
- Add a NodeManager
- Design a MissionGraph by adding and attaching nodes which contain functions. Nodes can be Stashes (contain a string such as a file path), StashIterators (contains an Expand or VariableGlob iterator), or be Agents(just a function which operates on remotely stored data).
- Then kick off the graph.
