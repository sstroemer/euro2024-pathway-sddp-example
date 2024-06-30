# Script

## Title

## Transition Paths vs. "Snapshots

## Overview: Types of Algorithms

### Conventional Optimization

Myopic transition path (pypsa):
- lock in
- co2 budget has to be decided upfront

Myopic (could have overlap -> MPC), ..., lock-in
adaptive temporal resolution + seasonal storage

annuities, vs. lump sum?
salvage values vs. is it actually worth something?

End of horizon effects?

### Simulation

ABM, AMIRIS

# Reducing the resolution

x hour blocks (even up to months)

can be variable

manually setting the cyclic state

Like SPINE (old?) : assume all decisions are as they are in the repr. snapshot, and only keep the storge variables
(can be used with "slow" technologies, but not enough studied if that works)

WHen comparing results, don't compare investment decisions, and if you do be careful.

### Decomposition

temporal, spatial, sectorial, mixed

Benders, ADMM => image with "process" (top down vs. consensus/exchange)

### Dual Dynamic Programming

=> SDDP + example

con: Relatively complete recourse (One definition of relatively complete recourse is that all feasible decisions (not necessarily optimal) in a subproblem lead to feasible decisions in future subproblems.)
con: stability, scaling, 

Here-and-now and hazard-decision

cvar

