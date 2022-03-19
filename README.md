# Just browsing

Touchscreen-friendly wrapper around Webkit

## TO DO

* functional

	- find out if it's going to eat cpu like luakit does
	- some kind of bookmarks/favourites/pinned tabs/memory of visited sites
	- try video and audio
	- does it save passwords? find out! where?
	- make adblock more effective

* cosmetic
	- swipe: animate
	- better icon for overview button
	- warning for insecure sites
    - improve the download

* architectural
    - redesign :-)
    - some affordance for customization seams (hooks or subclasses or ...)
	- "download" should not be in webview.fnl


## Notes to self

To get an interactive repl in running code (e.g. to inspect
values in a callback)


```
(local { : repl : view } (require :fennel))
(repl {:env {:view view :other other :vars vars :of-interest of-interest}})
```
