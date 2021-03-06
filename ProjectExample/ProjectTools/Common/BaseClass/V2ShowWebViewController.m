//
//  V2ShowWebViewController.m
//  ProjectTools
//
//  Created by Vols on 2015/12/9.
//  Copyright © 2015年 Vols. All rights reserved.
//

#import "V2ShowWebViewController.h"
#import <WebKit/WebKit.h>
#import <WebKit/WKWebView.h>

typedef NS_ENUM(NSUInteger, LoadWebType) {
    LoadWebTypeURL,
    LoadWebTypeHTML,
    LoadWebTypeURLPOST,
};

@interface V2ShowWebViewController ()<WKNavigationDelegate,WKUIDelegate,WKScriptMessageHandler,UINavigationControllerDelegate,UINavigationBarDelegate>

@property (nonatomic, strong) WKWebView     * wkWebView;
@property (nonatomic, strong) UIProgressView * progressView;

@property (nonatomic, assign) BOOL needLoadJSPOST;

@property (nonatomic, assign) LoadWebType loadType;

@property (nonatomic,   copy) NSString  *URLString;
@property (nonatomic,   copy) NSString  *postData;

@property (nonatomic, strong) NSMutableArray    * snapShotsArray;

@property (nonatomic, strong) UIBarButtonItem   * customBackBarItem;
@property (nonatomic, strong) UIBarButtonItem   * closeButtonItem;

@end

@implementation V2ShowWebViewController

#pragma mark - View Lifecycle

//注意，观察的移除
-(void)dealloc{
    [self.wkWebView removeObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress))];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initData];
    [self configureViews];

}

-(void)viewWillDisappear:(BOOL)animated {
    [self.wkWebView.configuration.userContentController removeScriptMessageHandlerForName:@"WXPay"];
    [self.wkWebView setNavigationDelegate:nil];
    [self.wkWebView setUIDelegate:nil];
}


- (void)initData {
    
}

- (void)configureViews {
    
    UIBarButtonItem *refreshBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadWebView)];
    self.navigationItem.rightBarButtonItem = refreshBtn;

    [self.view addSubview:self.wkWebView];
    [self.wkWebView addSubview:self.progressView];
    
    NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.URLString] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
    [self.wkWebView loadRequest:request];

    
//    if (_loadType == LoadWebTypeURL) {
//        NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.URLString] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10];
//        [self.wkWebView loadRequest:request];
//    }
//    else if (_loadType == LoadWebTypeHTML) {
//        [self loadHostPathURL:self.URLString];
//    }
//    else if (_loadType == LoadWebTypeURLPOST) {
//        self.needLoadJSPOST = YES;  // JS发送POST的Flag，为真的时候会调用JS的POST方法
//        [self loadHostPathURL:@"XFWKJSPOST"];   // POST使用预先加载本地JS方法的html实现，请确认XFWKJSPOST存在
//    }
}

- (void)loadHostPathURL:(NSString *)url {
    // 获取JS所在的路径
    NSString *jsPath = [[NSBundle mainBundle] pathForResource:url ofType:@"html"];
    NSString *html = [[NSString alloc] initWithContentsOfFile:jsPath encoding:NSUTF8StringEncoding error:nil];
    //加载js
    [self.wkWebView loadHTMLString:html baseURL:[[NSBundle mainBundle] bundleURL]];
}


// 调用JS发送POST请求
- (void)postRequestWithJS {
    // 拼装成调用JavaScript的字符串
    NSString *jscript = [NSString stringWithFormat:@"post('%@',{%@});", self.URLString, self.postData];
    // 调用JS代码
    [self.wkWebView evaluateJavaScript:jscript completionHandler:^(id object, NSError * _Nullable error) {
    }];
}


- (void)loadWebURLSring:(NSString *)string{
    self.URLString = string;
    self.loadType = LoadWebTypeURL;
}

- (void)loadHTMLString:(NSString *)string{
    self.URLString = string;
    self.loadType = LoadWebTypeHTML;
}

- (void)postWebURLSring:(NSString *)string postData:(NSString *)postData{
    self.URLString = string;
    self.postData = postData;
    self.loadType = LoadWebTypeURLPOST;
}



#pragma mark - Actions

- (void)reloadWebView {
    [self.wkWebView reload];
}

- (void)backAction:(UIButton *)sender {
    if (self.wkWebView.goBack) {
        [self.wkWebView goBack];
    }
    else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)closeAction:(UIButton *)sender {
    [self.navigationController popViewControllerAnimated:YES];
}






#pragma mark - Properties

- (WKWebView *)wkWebView {
    if (_wkWebView == nil) {
        
        WKWebViewConfiguration * conf = [[WKWebViewConfiguration alloc]init];
        conf.allowsAirPlayForMediaPlayback = YES;   //允许视频播放
        conf.allowsInlineMediaPlayback = YES;       // 允许在线播放
        conf.selectionGranularity = YES;            // 允许可以与网页交互，选择视图
        conf.processPool = [[WKProcessPool alloc] init];   // web内容处理池

        //自定义配置,一般用于 js调用oc方法(OC拦截URL中的数据做自定义操作)
        WKUserContentController * userContentController = [[WKUserContentController alloc]init];
        // 添加消息处理，注意：self指代的对象需要遵守WKScriptMessageHandler协议，结束时需要移除
        [userContentController addScriptMessageHandler:self name:@"WXPay"];
        conf.suppressesIncrementalRendering = YES;   // 是否支持记忆读取
        conf.userContentController = userContentController; // 允许用户更改网页的设置
        
        _wkWebView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:conf];
        _wkWebView.backgroundColor = [UIColor colorWithRed:240.0/255 green:240.0/255 blue:240.0/255 alpha:1.0];
        _wkWebView.navigationDelegate = self;
        _wkWebView.UIDelegate = self;

        [_wkWebView addObserver:self forKeyPath:NSStringFromSelector(@selector(estimatedProgress)) options:0 context:nil];
        _wkWebView.allowsBackForwardNavigationGestures = YES;        // 开启手势触摸
        [_wkWebView sizeToFit];             //适应你设定的尺寸
    }
    return _wkWebView;
}

- (UIBarButtonItem *)customBackBarItem {
    if (_customBackBarItem == nil) {
        UIImage* backItemImage = [[UIImage imageNamed:@"backItemImage"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImage* backItemHlImage = [[UIImage imageNamed:@"backItemImage-hl"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        
        UIButton* backButton = [[UIButton alloc] init];
        [backButton setTitle:@"返回" forState:UIControlStateNormal];
        [backButton setTitleColor:self.navigationController.navigationBar.tintColor forState:UIControlStateNormal];
        [backButton setTitleColor:[self.navigationController.navigationBar.tintColor colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
        [backButton.titleLabel setFont:[UIFont systemFontOfSize:17]];
        [backButton setImage:backItemImage forState:UIControlStateNormal];
        [backButton setImage:backItemHlImage forState:UIControlStateHighlighted];
        [backButton sizeToFit];
        
        [backButton addTarget:self action:@selector(backAction:) forControlEvents:UIControlEventTouchUpInside];
        _customBackBarItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    }
    return _customBackBarItem;
}

- (UIProgressView *)progressView {
    if (_progressView == nil) {
        _progressView = [[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressView.frame = CGRectMake(0, 0, self.view.bounds.size.width, 2);
        [_progressView setTrackTintColor:[UIColor colorWithRed:240.0/255 green:240.0/255 blue:240.0/255 alpha:1.0]];
        _progressView.progressTintColor = [UIColor greenColor];
    }
    return _progressView;
}

- (UIBarButtonItem *)closeButtonItem {
    if (!_closeButtonItem) {
        _closeButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStylePlain target:self action:@selector(closeAction:)];
    }
    return _closeButtonItem;
}

- (NSMutableArray *)snapShotsArray {
    if (!_snapShotsArray) {
        _snapShotsArray = [NSMutableArray array];
    }
    return _snapShotsArray;
}

#pragma mark - 自定义返回/关闭按钮  

- (void)updateNavigationItems {
    if (self.wkWebView.canGoBack) {
        UIBarButtonItem *spaceButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        spaceButtonItem.width = -6.5;
        [self.navigationItem setLeftBarButtonItems:@[spaceButtonItem, self.customBackBarItem, self.closeButtonItem] animated:NO];
    }else{
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
        [self.navigationItem setLeftBarButtonItems:@[self.customBackBarItem]];
    }
}

#pragma mark - WKNavigationDelegate

// 开始加载
-(void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    self.progressView.hidden = NO;
}

//内容返回时调用
-(void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    
}

//这个是网页加载完成，导航的变化
-(void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation{
    /*
     主意：这个方法是当网页的内容全部显示（网页内的所有图片必须都正常显示）的时候调用（不是出现的时候就调用），否则不显示，或则部分显示时这个方法就不调用。
     */
    // 判断是否需要加载（仅在第一次加载）
//    if (self.needLoadJSPOST) {
//        // 调用使用JS发送POST请求的方法
////        [self postRequestWithJS];
//        // 将Flag置为NO（后面就不需要加载了）
//        self.needLoadJSPOST = NO;
//    }
    // 获取加载网页的标题
    self.title = self.wkWebView.title;
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    [self updateNavigationItems];
}


//服务器请求跳转的时候调用
-(void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {

}

//服务器开始请求的时候调用
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    //    NSString* orderInfo = [[AlipaySDK defaultService]fetchOrderInfoFromH5PayUrl:[navigationAction.request.URL absoluteString]];
    //    if (orderInfo.length > 0) {
    //        [self payWithUrlOrder:orderInfo];
    //    }

    [self updateNavigationItems];
    decisionHandler(WKNavigationActionPolicyAllow);
}

// 内容加载失败时候调用
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error{
    NSLog(@"页面加载超时");
}

//跳转失败的时候调用
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
}

//进度条
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    
}

#pragma mark - WKUIDelegate
// 获取js 里面的提示
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler{
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }]];
    
    [self presentViewController:alert animated:YES completion:NULL];
}

// js 信息的交流
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(NO);
    }]];
    [self presentViewController:alert animated:YES completion:NULL];
}

// 交互。可输入的文本。
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler{
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"textinput" message:@"JS调用输入框" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.textColor = [UIColor redColor];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler([[alert.textFields lastObject] text]);
    }]];
    
    [self presentViewController:alert animated:YES completion:NULL];
}


//KVO监听进度条
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(estimatedProgress))] && object == self.wkWebView) {
        [self.progressView setAlpha:1.0f];
        BOOL animated = self.wkWebView.estimatedProgress > self.progressView.progress;
        [self.progressView setProgress:self.wkWebView.estimatedProgress animated:animated];
        
        // Once complete, fade out UIProgressView
        if(self.wkWebView.estimatedProgress >= 1.0f) {
            [UIView animateWithDuration:0.3f delay:0.3f options:UIViewAnimationOptionCurveEaseOut animations:^{
                [self.progressView setAlpha:0.0f];
            } completion:^(BOOL finished) {
                [self.progressView setProgress:0.0f animated:NO];
            }];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


//拦截执行网页中的JS方法
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message{
    
    //服务器固定格式写法 window.webkit.messageHandlers.名字.postMessage(内容);
    //客户端写法 message.name isEqualToString:@"名字"]
    if ([message.name isEqualToString:@"WXPay"]) {
        NSLog(@"%@", message.body);
        //调用微信支付方法
        //        [self WXPayWithParam:message.body];
    }
}


#pragma mark - Helpers

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
