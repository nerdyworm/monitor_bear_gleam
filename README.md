# Bear

This is a nearly complete app written in Gleam with a Lustre SPA.

It contains all the moving parts needed to launch a project.

This repository is not intended to be perfect, as it was my first attempt at building something useful in Gleam.

This repo will not be maintained; it is meant to be a show-and-tell for the community.


# Building (Good Luck)

You'll need to build the Gleam compiler from source. This should be fine after the 1.1.0 -> 1.1.1 release.

```
make server
make spa
make worker
```

There are few environment variables that you'll need to set:
- DATABASE_URL
- DELIVER_EMAIL
- BEAR_INTERNAL_API_KEY
- BEAR_SECRET_KEY_BASE
- STRIPE_KEY
- STRIPE_WEBHOOK_SIGNING_KEY
- AWS_ACCESS_KEY
- AWS_SECRET_ACCESS_SECRET 

# Notes

I've spent more time thinking about UI work rather than server work. I wouldn't recommend using any of the current worker/queue code as a solid example of how to do anything valuable. It just happens to be what I was able to get working in a few weekends of work. It certainly works as is but requires additional effort.

Additionally, I wanted to experiment with not passing around a database connection on the back end. This feels somewhat contrary to the language's design, but having to pass it to every function that interacts with the database was cumbersome and didn't "spark joy," so to speak.

For the UI, I needed to add subscriptions and a full browser application to Lustre. I tried to replicate the latest version of Elm with their `Document {title, body}` structure. It kind of works, but it still needs some refinement.

## UI Stuff Implemented

- routing
- animated dropdown menus
- animated modal
- websocket updates
- page titles
- validation error messages

# Thanks

Special thanks to the gleam community.  They have built a wonderful ecosystem in a very short amount of time.  You should consider sponsoring them.

# Contact

Follow me on twitter: https://x.com/realbennyjamins


# Screenshots

![Checks Index](screenshots/Screenshot%20from%202024-05-18%2008-02-50.png)

![Checks Details](screenshots/Screenshot%20from%202024-05-18%2008-03-03.png)

More located in the screenshots directory.
