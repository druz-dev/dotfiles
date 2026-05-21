return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      clangd = {
        cmd = {
          "clangd",
          "--query-driver=**/aarch64-appear-linux-g++",
          "--clang-tidy",
        },
        autostart = true,
      },
    },
  },
}
