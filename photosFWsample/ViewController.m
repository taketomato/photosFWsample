#import "ViewController.h"
@import Photos;

NSString * const kMyAlbum = @"My Album";
NSString * const kFilterName = @"CISepiaTone";
NSString * const kAssetIdentifier = @"assetIdentifier";
NSString * const kAlbumIdentifier = @"albumIdentifier";

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
- (IBAction)makeAlbumTapped:(id)sender;
- (IBAction)readTapped:(id)sender;
- (IBAction)saveTapped:(id)sender;
- (IBAction)readLastSavedTapped:(id)sender;
@end

@implementation ViewController

#pragma mark === Life Cycle ===
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark === IBAction ===
- (IBAction)makeAlbumTapped:(id)sender {
    [self makeAlbumAction];
    [self accessCollecitonList];
}

- (IBAction)readTapped:(id)sender {
    [self readAction];
}

- (IBAction)saveTapped:(id)sender {
    [self saveAction];
}

- (IBAction)readLastSavedTapped:(id)sender {
    [self readLastSavedAction];
}

#pragma mark === Private ===
- (void)makeAlbumAction {
    NSLog(@"make album action");
    [self makeAlbumWithTitle:kMyAlbum];
}

- (void)readAction {
    NSLog(@"read action");
    
    // PHAssetを取得します
    PHFetchResult *assets = [PHAsset fetchAssetsInAssetCollection:[self getMyAlbum] options:nil];
    NSLog(@"assets.count = %lu", assets.count);
    if (assets.count == 0) {
        [self showMessage:@"No Image in My Album."];
        return;
    }
    
    // assets を取り出します
    NSArray * assetArray = [self getAssets:assets];
    
    // UIImageView をランダムに更新します
    [self updateImageViewWithAsset:assetArray[arc4random() % assets.count]];
}

- (void)saveAction {
    NSLog(@"save action");
    if (!self.imageView.image) return;
    UIImage * inputImage = [self filter:self.imageView.image];
    [self addNewAssetWithImage:inputImage toAlbum:[self getMyAlbum]];
}

- (void)readLastSavedAction {
    NSLog(@"read last saved action");
    
    // Identifier を指定して PHAsset のフェッチリザルトを受け取ります
    NSString * identifier = [[NSUserDefaults standardUserDefaults]objectForKey:kAssetIdentifier];
    if (!identifier) return;
    PHFetchResult *assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[identifier] options:nil];
    NSLog(@"assets.count = %lu", assets.count);
    if (assets.count == 0) return;
    
    // assets を取り出します
    NSArray * assetArray = [self getAssets:assets];
    
    // UIImageView を更新します
    [self updateImageViewWithAsset:assetArray.lastObject];
}

- (void)makeAlbumWithTitle:(NSString *)title
{
    if ([self getMyAlbum]) {
        [self showMessage:@"My Album already exists."];
        return;
    }
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        // Request editing the album.
        PHAssetCollectionChangeRequest *createAlbumRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:title];
        
        // Get a placeholder for the new asset and add it to the album editing request.
        PHObjectPlaceholder * placeHolder = [createAlbumRequest placeholderForCreatedAssetCollection];
        
        // identifier を USerDefaults に保存します
        NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:placeHolder.localIdentifier forKey:kAlbumIdentifier];
        [defaults synchronize];
        
    } completionHandler:^(BOOL success, NSError *error) {
        NSLog(@"Finished adding asset. %@", (success ? @"Success" : error));
    }];
}

- (void)addNewAssetWithImage:(UIImage *)image toAlbum:(PHAssetCollection *)album
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        // Request creating an asset from the image.
        PHAssetChangeRequest *createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        
        // Request editing the album.
        PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:album];
        
        // Get a placeholder for the new asset and add it to the album editing request.
        PHObjectPlaceholder * placeHolder = [createAssetRequest placeholderForCreatedAsset];
        [albumChangeRequest addAssets:@[ placeHolder ]];
        
        // identifier を USerDefaults に保存します
        NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:placeHolder.localIdentifier forKey:kAssetIdentifier];
        [defaults synchronize];
        
    } completionHandler:^(BOOL success, NSError *error) {
        NSLog(@"Finished adding asset. %@", (success ? @"Success" : error));
    }];
}

- (UIImage *)filter:(UIImage *)inputUIImage{
    CIFilter *filter = [CIFilter filterWithName:kFilterName];
    [filter setDefaults];
    CIImage *inputImage = [CIImage imageWithCGImage:inputUIImage.CGImage];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    CIImage *outputImage = [filter outputImage];
    
    // convert to UIImage
    // http://stackoverflow.com/questions/7788438/having-trouble-creating-uiimage-from-ciimage-in-ios5
    CIContext *context = [CIContext contextWithOptions:nil];
    UIImage *outputUIImage = [UIImage imageWithCGImage:[context createCGImage:outputImage fromRect:outputImage.extent]];
    
    return outputUIImage;
}

/**
 * @brief [My Album]を取得します
 */
- (PHAssetCollection *)getMyAlbum {
#if 0
    // identifier を使ってユーザ作成のアルバムを取得します
    NSString * identifier = [[NSUserDefaults standardUserDefaults]objectForKey:kAlbumIdentifier];
    if (!identifier) return nil;
    PHFetchResult *assetCollections = [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[identifier]
                                                                                           options:nil];
#else
    // ユーザ作成のアルバム一覧を取得します
    PHFetchResult *assetCollections = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                                               subtype:PHAssetCollectionSubtypeAlbumRegular
                                                                               options:nil];
#endif
    NSLog(@"assetCollections.count = %lu", assetCollections.count);
    if (assetCollections.count == 0) return nil;
    
    // [MyAlbum]の AssetCollection を取得します
    __block PHAssetCollection * myAlbum;
    [assetCollections enumerateObjectsUsingBlock:^(PHAssetCollection *album, NSUInteger idx, BOOL *stop) {
        NSLog(@"album:%@", album);
        NSLog(@"album.localizedTitle:%@", album.localizedTitle);
        if ([album.localizedTitle isEqualToString:kMyAlbum]) {
            myAlbum = album;
            *stop = YES;
        }
    }];
    
    if (!myAlbum) return nil;
    return myAlbum;
}

/**
 * @brief asset を配列に格納します
 */
- (NSArray *)getAssets:(PHFetchResult *)fetch {
    __block NSMutableArray * assetArray = NSMutableArray.new;
    [fetch enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL *stop) {
        NSLog(@"asset:%@", asset);
        [assetArray addObject:asset];
    }];
    return assetArray;
}

/**
 * @brief 指定の asset を UIImageView に表示します
 */
- (void)updateImageViewWithAsset:(PHAsset *)asset {
    typeof(self) __weak wself = self;
    [[PHImageManager defaultManager] requestImageForAsset:asset
                                               targetSize:CGSizeMake(300,300)
                                              contentMode:PHImageContentModeAspectFill
                                                  options:nil
                                            resultHandler:^(UIImage *result, NSDictionary *info) {
                                                if (result) {
                                                    wself.imageView.image = result;
                                                }
                                            }];
}

- (void)showMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@""
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)accessCollecitonList {
    PHFetchResult *lists = [PHCollectionList fetchCollectionListsWithType:PHCollectionListTypeSmartFolder
                                                                   subtype:PHCollectionListSubtypeSmartFolderEvents
                                                                   options:nil];
    NSLog(@"collectionList.count = %lu", lists.count);
    if (lists.count == 0) return;
    [lists enumerateObjectsUsingBlock:^(PHCollectionList *collectionList, NSUInteger idx, BOOL *stop) {
        NSLog(@"collectionList:%@", collectionList);
        NSLog(@"collectionList.localizedTitle:%@", collectionList.localizedTitle);
    }];
}
@end
