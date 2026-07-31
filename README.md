# sv

Everything you need to build a Svelte project, powered by [`sv`](https://github.com/sveltejs/cli).

## Creating a project

If you're seeing this, you've probably already done this step. Congrats!

```sh
# create a new project
npx sv create my-app
```

To recreate this project with the same configuration:

```sh
# recreate this project
npx sv@0.16.6 create --template demo --types ts --install npm my-app
```

## Developing

Once you've created a project and installed dependencies with `npm install` (or `pnpm install` or `yarn`), start a development server:

```sh
npm run dev

# or start the server and open the app in a new browser tab
npm run dev -- --open
```

## Building

To create a production version of your app:

```sh
npm run build
```

You can preview the production build with `npm run preview`.

The project uses [`@sveltejs/adapter-node`](https://svelte.dev/docs/kit/adapter-node), so `npm run build`
produces a standalone Node server in `build/` (`node build/index.js`).

## Running under ShinyProxy

### Build the image

```sh
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/baldikacti/shinyproxy-sveltekit-demo:latest \
  --push .
```

```sh
docker run --rm -p 3000:3000 ghcr.io/baldikacti/shinyproxy-sveltekit-demo:latest
```

### The sub-path problem

ShinyProxy gives each session its own sub-path (`/app_proxy/<proxy-id>/`), and SvelteKit bakes
`paths.base` into the build — a value that cannot be known when the image is built. The image
therefore builds with a placeholder base path, and `docker-entrypoint.sh` rewrites the build output
(asset directories, server bundle, prerendered HTML) with the real sub-path before starting the
server. It reads that path from `SHINYPROXY_PUBLIC_PATH`; when the variable is absent the app is
served from `/` instead.

Two settings in the app spec make this work — see [shinyproxy/application.yml](shinyproxy/application.yml)
for the complete example:

```yaml
# Forward the sub-path to the container instead of stripping it, ...
target-path: "#{proxy.getRuntimeValue('SHINYPROXY_PUBLIC_PATH')}"
container-env:
  # ... and tell the app which sub-path it is being served on.
  SHINYPROXY_PUBLIC_PATH: "#{proxy.getRuntimeValue('SHINYPROXY_PUBLIC_PATH')}"
```

### Environment variables

| Variable                 | Default            | Purpose                                                          |
| ------------------------ | ------------------ | ---------------------------------------------------------------- |
| `SHINYPROXY_PUBLIC_PATH` | _(unset)_          | Sub-path the app is served on; injected by ShinyProxy.            |
| `BASE_PATH`              | _(unset)_          | Overrides the above, for testing a sub-path outside ShinyProxy.   |
| `PORT` / `HOST`          | `3000` / `0.0.0.0` | Must match `port:` in the app spec.                               |
| `ORIGIN`                 | _(unset)_          | Public ShinyProxy URL. Set it if form posts fail with a 403 — the image otherwise derives the origin from `x-forwarded-proto` / `x-forwarded-host`. |
