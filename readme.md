# DayBlocks

Simple time-tracker in your terminal.

![DayBlocks in action](/dayblocks.png "DayBlocks in action")

## Usage ##

Type *help* to see all possible commands.

Type *print* to show all minutes in your current day, separated into 1-hour blocks. each minute is colored to show:
1. Sleep time (preset 23:00-8:00)
2. Free time (preset - everything that's not sleep)
3. Work (timed by the user)
4. Break (timed by the user)


It's not customisable at all and I like it that way. A non-feature missing from most applications these days.


Type *start* [work/break] to start timing, type *stop* to stop timing. *quit* to exit the app. Everything is saved to a file, in plain text format (similar to what you get when you *print*) - and that's it! Nothing more! How much I miss simple tech that just does what's needed, without having to create an account, log in every time, customize everything. It also doesn't take more than a split second to start up/react to your clicks... <sub><sup>Actually, it takes some time to print the whole table because I'm printing each line separately, I like to pretend it's an animation...</sup></sub>

Everything is stored in a plain text file right next to the executable which can be manually edited if needed.

## Bugs ##

I keep getting read input error 6 despite everything working correctly.

Timing will surely break if you start timing on one day and finish on another but it's okay because you should be sleeping at night.
This was introduced because of my poor engineering but I like it, forces me to go to bed at midnight at the latest.
