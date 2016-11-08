//
//  ViewController.m
//  Xcode78IBSwitch
//
//  Created by dfpo on 16/10/23.
//  Copyright © 2016年 dfpo. All rights reserved.
//

#import "ViewController.h"

@interface ViewController()<NSPathControlDelegate, NSTableViewDataSource, NSTabViewDelegate>

/**
 *   选择路径
 */
@property (weak) IBOutlet NSButton *choosePathBtn;

@property (weak) IBOutlet NSButton *chooseTypeBtn;

/**
 *  路径处理控件
 */
@property (weak) IBOutlet NSPathControl *pathControl;
/**
 *  7 -> 7 to 8 , 8 -> 8 to 7
 */
@property (nonatomic) NSInteger startXcodeVersion;

@property (weak) IBOutlet NSTableView *tableView;

@property (nonatomic) NSMutableDictionary<NSString *, NSString *>  *fileDict;

@property (weak) IBOutlet NSMatrix *chooseTypeControl;

@end
@implementation ViewController
- (void)awakeFromNib {
    [super awakeFromNib];
    
    [self.pathControl setDoubleAction:@selector(pathControlDoubleClick:)];

}
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.choosePathBtn.attributedTitle =
    [self btnAttributedStringWithtitle:@"choose a path"];
    [self makeRound:self.choosePathBtn];
    self.fileDict = @{}.mutableCopy;
    self.startXcodeVersion = 7;
}

#pragma mark - action
- (IBAction)clickChooseAPathBtn:(NSButton *)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:YES];
    [panel setResolvesAliases:YES];
    
    NSString *panelTitle = NSLocalizedString(@"Choose a file", @"Title for the open panel");
    [panel setTitle:panelTitle];
    
    NSString *promptString = NSLocalizedString(@"Choose", @"Prompt for the open panel prompt");
    [panel setPrompt:promptString];
    
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        
        // Hide the open panel.
        [panel orderOut:self];
        
        if (result != NSModalResponseOK) {
            return;
        }
        // Get the first URL returned from the Open Panel and set it at the first path component of the control.
        NSURL *url = [[panel URLs] objectAtIndex:0];
        [self.pathControl setURL:url];
        NSOperationQueue *taskQueue = [[NSOperationQueue alloc] init];
        NSBlockOperation *dataOp = [NSBlockOperation blockOperationWithBlock:^{
            
            [self dealWithPath:url.path];
        }];
        NSBlockOperation *refreshOp = [NSBlockOperation blockOperationWithBlock:^{
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                
                //刷新NSTableView
                [self.tableView reloadData];
                //响应新的选择
                [self refreshSelection];
            }];
        }];
        [refreshOp addDependency:dataOp];
        [taskQueue addOperation:dataOp];
        [taskQueue addOperation:refreshOp];

    }];
}
//NSTableViewDelegate中选择改变回调
- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    [self refreshSelection];
}

//刷新选择
- (void)refreshSelection {
    
    if (self.tableView.selectedRow >= 0) {
        //有选择
    } else {
        //无选择
    }
}
- (IBAction)takeStyleFrom:(NSMatrix *)sender
{
    NSInteger tag = [[sender selectedCell] tag];
    self.startXcodeVersion = tag;
}
- (IBAction)clickStartConvertBtn:(NSButton *)sender {
    self.choosePathBtn.enabled = NO;
    self.pathControl.enabled = NO;
    self.chooseTypeBtn.enabled = NO;
    self.chooseTypeControl.enabled = NO;

    NSOperationQueue *q = [[NSOperationQueue alloc] init];
    NSBlockOperation *UIOp = [NSBlockOperation blockOperationWithBlock:^{
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            
            self.choosePathBtn.enabled = YES;
            self.pathControl.enabled = YES;
            self.chooseTypeBtn.enabled = YES;
            self.chooseTypeControl.enabled = YES;
            NSAlert *alert = [[NSAlert alloc]init];
            
            alert.messageText = @"处理完毕！";
            [alert addButtonWithTitle:@"好的"];
            alert.alertStyle = NSWarningAlertStyle;
            [alert runModal];
        }];
    }];
    NSBlockOperation *taskOp = [NSBlockOperation blockOperationWithBlock:^{
        [self.fileDict.allValues enumerateObjectsUsingBlock:^(NSString * _Nonnull filePath, NSUInteger idx, BOOL * _Nonnull stop) {
            
            // 加载文件内容
            NSString *content =
            [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
            
            // Xcode 7.3.1 7D1014
            NSString *str2 =
            @"<capability name=\"Constraints to layout margins\" minToolsVersion=\"6.0\"/>";
            
            // Xcode 8.0 8A218a
            NSString *str4 =
            @"<capability name=\"documents saved in the Xcode 8 format\" minToolsVersion=\"8.0\"/>";
            NSString *outString = @"";
            
            if (self.startXcodeVersion == 7) {
                
                outString =
                [content stringByReplacingOccurrencesOfString:str2 withString:str4];
                
                
            } else if (self.startXcodeVersion == 8) {
                
                
                outString =
                [content stringByReplacingOccurrencesOfString:str4 withString:str2];
                
            } else  {
                
                NSAlert *alert = [[NSAlert alloc]init];
                
                alert.messageText = @"发现一个未知情况";
                [alert addButtonWithTitle:@"好的"];
                alert.alertStyle = NSWarningAlertStyle;
                [alert runModal];
            }
            // 写入
            NSError *error = nil;
            NSString *strf = [NSString stringWithFormat:@"file://%@", filePath];
            [outString writeToURL:[NSURL URLWithString:strf] atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                NSAlert *alert = [[NSAlert alloc]init];
                
                alert.messageText = error.localizedDescription;
                [alert addButtonWithTitle:@"好的"];
                alert.alertStyle = NSWarningAlertStyle;
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    
                    [alert runModal];
                }];
            }
        }];
    }];
    [UIOp addDependency:taskOp];
    [q addOperation:taskOp];
    [q addOperation:UIOp];
}
- (void)dealWithPath:(NSString *)path {

    NSFileManager *mgr = [NSFileManager defaultManager];
    
    /// 是否为文件夹
    BOOL dir = NO;
    
    /// 路径是否存在
    BOOL exist = [mgr fileExistsAtPath:path isDirectory:&dir];
    
    // 如果不存在，直接返回0
    if(!exist)
    {
        NSLog(@"%@,文件路径不存在!!!!!!", path);
        return ;
    }
    if (dir)
    { // 文件夹
        // 获得当前文件夹path下面的所有内容（文件夹、文件）
        NSArray *array = [mgr contentsOfDirectoryAtPath:path error:nil];
        
        // 遍历数组中的所有子文件（夹）名
        [array enumerateObjectsUsingBlock:^(NSString  *_Nonnull filename, NSUInteger idx, BOOL * _Nonnull stop) {
            // 获得子文件（夹）的全路径
            NSString *fullPath = [NSString stringWithFormat:@"%@/%@", path, filename];

                
                [self dealWithPath:fullPath];
        
        }];
        
    }
    else
    { // 文件
        // 判断文件的拓展名(忽略大小写)
        NSString *extension = [[path pathExtension] lowercaseString];
        if (![extension isEqualToString:@"xib"] &&
            ![extension isEqualToString:@"storyboard"])
        {
            // 只处 xib sb文件
            return ;
        }
        NSString *fileName = path.lastPathComponent;
        NSString *filePath = path;
        
        self.fileDict[fileName] = filePath;
        
       
    }
    
}
- (IBAction)pathControlSingleClick:(id)sender {

    [self.pathControl setURL:[[self.pathControl clickedPathComponentCell] URL]];
}

- (void)pathControlDoubleClick:(id)sender {
    if ([self.pathControl clickedPathComponentCell] == nil) {
        
        return;
    }
    [[NSWorkspace sharedWorkspace] openURL:[self.pathControl URL]];
}
#pragma mark - table
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.fileDict.allKeys.count;
}
- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    NSString *identifier = tableColumn.identifier;

    NSTableCellView *cellView = nil;
    if ([identifier isEqualToString:@"fileName"]) {
         cellView  = [tableView makeViewWithIdentifier:@"fileName" owner:self];
        if (self.fileDict.count > row) {
            
            cellView.textField.stringValue = self.fileDict.allKeys[row];
        }
        return cellView;
    }
    if ([identifier isEqualToString:@"path"]) {
        cellView      = [tableView makeViewWithIdentifier:@"path" owner:self];
        if (self.fileDict.count > row) {
        
            cellView.textField.stringValue = self.fileDict[self.fileDict.allKeys[row]];
        }
        return cellView;
    }
    return cellView;
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *identifier = [tableColumn identifier];
    tableColumn.title = @"f";
    tableColumn.headerCell.title = @"xx";
    if ([identifier isEqualToString:@"fileName"]) {
        NSTextFieldCell *textCell = cell;
        [textCell setTitle:@"fff"];
    }
    else if ([identifier isEqualToString:@"path"])
    {
        NSTextFieldCell *textCell = cell;
        [textCell setTitle:@"zz"];
    }
}
#pragma mark - private
- (NSAttributedString *)btnAttributedStringWithtitle:(NSString *)title  {
    
    NSFont *font = [NSFont fontWithName:@"Times New Roman" size:16];
    NSDictionary *dict = @{NSFontAttributeName: font,
                           NSForegroundColorAttributeName:[NSColor blackColor]};
    
    return [[NSAttributedString alloc]initWithString:title
                                          attributes:dict];
}


- (void)makeRound:(NSView*)view {
    
    view.layer.masksToBounds = YES;
    view.layer.cornerRadius = 10;
    view.layer.borderWidth = 5;
    view.layer.borderColor = [NSColor redColor].CGColor;
    view.layer.backgroundColor = [NSColor blueColor].CGColor;

}

@end
