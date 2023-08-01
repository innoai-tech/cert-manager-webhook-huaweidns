package main

import (
	"strings"

	"wagon.octohelm.tech/core"

	"github.com/innoai-tech/runtime/cuepkg/golang"

	"github.com/innoai-tech/cert-manager-webhook-huaweidns/cuepkg/webhook"
	"github.com/innoai-tech/cert-manager-webhook-huaweidns/cuedevpkg/tool"
)

pkg: version: core.#Version & {
}

actions: go: golang.#Project & {
	source: {
		path: "."
		include: [
			"cmd/",
			"go.mod",
			"go.sum",
		]
	}

	version: pkg.version.output

	goos: ["linux"]
	goarch: ["amd64", "arm64"]
	main: "./cmd/webhook"

	ldflags: [
		"""
			-w -extldflags "-static"
			""",
	]

	build: pre: [
		"go mod download",
	]

	ship: {
		name: "\(strings.Replace(go.module, "github.com/", "ghcr.io/", -1))"
		tag:  pkg.version.output
		from: "gcr.io/distroless/static-debian11:debug"
		config: {
			workdir: "/"
			cmd: ["webhook"]
		}
	}
}

actions: export: tool.#Export & {
	name:      "cert-manager-webhook-huaweidns"
	namespace: "cert-manager"
	kubepkg:   webhook.#Webhook & {
		#values: {
		}
		spec: version: pkg.version.output
	}
}

setting: {
	_env: core.#ClientEnv & {
		GH_USERNAME: string | *""
		GH_PASSWORD: core.#Secret
	}

	setup: core.#Setting & {
		registry: "ghcr.io": auth: {
			username: _env.GH_USERNAME
			secret:   _env.GH_PASSWORD
		}
	}
}
