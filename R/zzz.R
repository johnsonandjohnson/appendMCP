.onAttach <- function(libname, pkgname) {
  packageStartupMessage(
    rep("-", 105), "\n",
    "appendMCP: Tools for defining graphical multiple testing procedures in group-sequentially designed trials",
    "\n", rep("-", 105), "\n",
    "                                                            _   __  __    _____   _____
                                                           | | |  \\/  |  / ____| |  __ \\
                  __ _   _ __    _ __     ___   _ __     __| | | \\  / | | |      | |__) |
                 / _` | | '_ \\  | '_ \\   / _ \\ | '_ \\   / _` | | |\\/| | | |      |  ___/
                | (_| | | |_) | | |_) | |  __/ | | | | | (_| | | |  | | | |____  | |
                 \\__,_| | .__/  | .__/   \\___| |_| |_|  \\__,_| |_|  |_|  \\_____| |_|
                        | |     | |
                        |_|     |_|
    ", "\n",
    rep("-", 105), "\n\n",
    "v0.3.0: For an overview of the package's functionality enter: ?appendMCP")
}
