import java.io.*;
import java.net.*;

public class HttpTest {
    public static void main(String[] args) throws Exception {
        URL url = new URL(args[0]);
        url.openConnection().getContent();
    }
}
