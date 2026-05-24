import Hummingbird

func configureRoutes(_ router: Router<some RequestContext>) {
    let documentController = DocumentController()
    let checkInOutController = CheckInOutController()
    let versionController = VersionController()
    let folderController = FolderController()
    let templateController = TemplateController()
    let searchController = SearchController()
    let systemController = SystemController()

    documentController.registerRoutes(router)
    checkInOutController.registerRoutes(router)
    versionController.registerRoutes(router)
    folderController.registerRoutes(router)
    templateController.registerRoutes(router)
    searchController.registerRoutes(router)
    systemController.registerRoutes(router)
}
