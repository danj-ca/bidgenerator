#BiD Generator
##An extremely simple static site generator for bobisdoomed.com

###What?
[Bob is Doomed](http://bobisdoomed.com) is a humourous comic strip about a desperate man and the manifold perils he encounters as an office drone in a world going mad. **bidgenerator** is a Ruby script that applies a template to a set of comic strips, producing a static website.

###Why?
While a huge number of comic-strip sites run on [Wordpress](http://wordpress.org) using the [ComicPress](http://comicpress.org) or [Easel](http://frumph.net/easel/) themes, these have a few disadvantages:

  - They require one to host and maintain Wordpress, its dependencies, the respective theme, and a bevy of plugins
  - The dynamically-generated nature of the resulting site carries considerable performance overhead, usually mitigated by bolting on additonal Wordpress plugins
  - The resulting websites, all born from a common theme, look extremely similar unless considerable work is done to create a unique child theme

Nonetheless, most amateur comic creators are neither web designers nor developers: they have to take what they can get, unless they can afford to hire professionals. As a developer, I have an alternative. Building my own site generator has a few advantages:

  - It gives me a chance to build something using Ruby, a language to which I'd like to gain more exposure
  - I gives me a chance to improve my front-end web development skills
  - The resulting site is extremely fast, amenable to optimizations like caching proxies, and can be hosted basically anywhere
  - With full control over the generated CSS, HTML, etc., I can develop and deploy changes rapidly, and rolling back is as simple as replacing the static files from backup