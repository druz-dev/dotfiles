return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      clangd = {
        cmd = {
          "clangd",
          "--query-driver=**/aarch64-appear-linux-*",
          "--clang-tidy",
        },
        autostart = true,
      },
    },
  },
}
