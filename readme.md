# DayBlocks

Simple time-tracker for your terminal.

![DayBlocks in action](/dayblocks.png "DayBlocks in action")

## Usage ##

Type *help* to see all possible commands.

Type *print* to show all minutes in your current day, separated into 1-hour blocks. each minute is colored to show:
1. Sleep time (preset 23:00-8:00)
2. Free time (preset - everything that's not sleep)
3. Work (timed by the user)
4. Break (timed by the user)


It's not customisable at all and I like it that way. A non-feature missing from most applications these days.


Type *start* [work/break] to start timing, type *stop* to stop timing. *quit* to exit the app. 
Everything is saved to a file, in plain text format (similar to what you get when you *print*) - and that's it! Nothing more! 

Everything is stored in a plain text file right next to the executable which can be manually edited if needed.

## Bugs ##

* Timing will surely break if you start timing on one day and finish on another but it's okay because you should be sleeping at night.
* There *may* be something wrong with daylight saving time, not sure. Will check in the summer...
