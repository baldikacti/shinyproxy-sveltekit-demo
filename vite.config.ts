import adapter from '@sveltejs/adapter-node';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

// ShinyProxy serves each app on a per-session sub-path (`/app_proxy/<proxy-id>/`) that is only
// known at container start-up, but SvelteKit bakes `paths.base` into the build. We therefore build
// with a placeholder base and rewrite it in the build output at start-up (see docker-entrypoint.sh).
// BASE_PATH stays empty for local `npm run build`, so nothing changes outside of Docker.
const base = process.env.BASE_PATH ?? '';

export default defineConfig({
	plugins: [
		sveltekit({
			compilerOptions: {
				// Force runes mode for the project, except for libraries. Can be removed in svelte 6.
				runes: ({ filename }) =>
					filename.split(/[/\\]/).includes('node_modules') ? undefined : true
			},

			// adapter-node produces a standalone Node server, which is what runs inside the
			// container that ShinyProxy launches.
			// See https://svelte.dev/docs/kit/adapters for more information about adapters.
			adapter: adapter(),

			paths: {
				base
			}
		})
	]
});
