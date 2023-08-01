package tool

import (
	"path"
	"strings"
	"encoding/json"

	"wagon.octohelm.tech/core"

	spec "github.com/octohelm/kubepkg/cuepkg/kubepkg"
)

#Export: {
	name:      string
	namespace: string

	platforms: [...string] | *["linux/amd64", "linux/arm64"]

	kubepkg: spec.#KubePkg | spec.#KubePkgList

	_files: "/src/kubepkg.json": core.#WriteFile & {
		contents: json.Marshal([

			if (kubepkg & spec.#KubePkg) != _|_ {
				kubepkg & {
					metadata: "namespace": "\(namespace)"
				}
			},

			if (kubepkg & spec.#KubePkgList) != _|_ {
				spec.#KubePkgList & {
					items: [
						for k in kubepkg.items {
							k & {
								metadata: "namespace": "\(namespace)"
							}
						},
					]
				}
			},
			{},
		][0])
		path: "kubepkg.json"
	}

	airgap: {
		_env: core.#ClientEnv & {
			KUBEPKG_REMOTE_REGISTRY_ENDPOINT: _ | *""
			KUBEPKG_REMOTE_REGISTRY_USERNAME: _ | *""
			KUBEPKG_REMOTE_REGISTRY_PASSWORD: core.#Secret
		}

		_airgap: {
			for p in platforms {
				"\(p)": {
					_image: #Image & {
						platform: "\(p)"
					}

					_run: #Run & {
						input: _image.output
						mounts: {
							for p, f in _files {
								"\(p)": core.#Mount & {
									dest:     p
									source:   f.path
									contents: f.output
								}
							}

							"kubepkg-storage": core.#Mount & {
								dest:     "/etc/kubepkg"
								contents: core.#CacheDir & {
									id: "kubepkg-storage"
								}
							}
						}
						env: {
							KUBEPKG_REMOTE_REGISTRY_ENDPOINT: _env.KUBEPKG_REMOTE_REGISTRY_ENDPOINT
							KUBEPKG_REMOTE_REGISTRY_USERNAME: _env.KUBEPKG_REMOTE_REGISTRY_USERNAME
							KUBEPKG_REMOTE_REGISTRY_PASSWORD: _env.KUBEPKG_REMOTE_REGISTRY_PASSWORD
						}
						command: {
							"name": "export"
							args: [
								"--storage-root=/etc/kubepkg",
								"--output-oci=/build/images/\(p)/\(name).airgap.tar",
								"--platform=\(p)",
								"/src/kubepkg.json",
							]
						}
					}

					_copy: core.#Copy & {
						contents: _run.output.rootfs
						source:   "/build"
						dest:     "/"
					}

					output: _copy.output
				}
			}
		}

		_merge: core.#Merge & {
			inputs: [
				for p in platforms {
					_airgap["\(p)"].output
				},
			]
		}

		output: _merge.output
	}

	manifests: {
		_image: #Image & {}

		_run: #Run & {
			input: _image.output
			mounts: {
				for p, f in _files {
					"\(p)": core.#Mount & {
						dest:     p
						source:   f.path
						contents: f.output
					}
				}
			}
			command: {
				"name": "export"
				args: [
					"--platform=\(strings.Join(platforms, ","))",
					"--output-manifests=/build/manifests/\(path.Base(name)).yaml",
					"--output-dir-external-config=/build/external-configs/",
					"/src/kubepkg.json",
				]
			}
		}

		_copy: core.#Copy & {
			contents: _run.output.rootfs
			source:   "/build"
			dest:     "/"
		}

		output: _copy.output
	}

	all: core.#Merge & {
		inputs: [
			airgap.output,
			manifests.output,
		]
	}
}
