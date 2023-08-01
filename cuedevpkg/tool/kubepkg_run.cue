package tool

import (
	"wagon.octohelm.tech/docker"
)

#DefaultTag: "v0.5.4-0.20230801041258-e2b3c1b81449"

#Run: {
	tag: string | *#DefaultTag

	docker.#Run & {
		workdir: "/build"
	}
}

#Image: {
	tag: string | *#DefaultTag

	docker.#Pull & {
		source: _ | *"ghcr.io/octohelm/kubepkg:\(tag)"
	}
}
